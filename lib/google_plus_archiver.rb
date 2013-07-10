require 'json'
require 'net/http'
require 'tempfile'
require 'tmpdir'
require 'zlib'

require 'google/api_client'

require 'archive/tar/minitar'
include Archive::Tar

module GooglePlusArchiver
  
  def self.api_key
    @@api_key
  end
  
  def self.api_key=(api_key)
    @@api_key = @@client.key = api_key
  end
  
  def self.request_num
    @@request_num
  end
  
  def self.register_client(api_key)
    @@client = Google::APIClient.new(:application_name => 'GooglePlusArchiver', :application_version => VERSION)
    @@api_key = @@client.key = api_key
    @@request_num = 0
    begin
      @@plus = @@client.discovered_api('plus')
    rescue
      puts "Invalid Google API key."
    end
  end
  
  def self.client_registered?
    defined? @@plus
  end
  
  def self.get_full_image_url(url)
    if url =~ /https:\/\/\w+\.googleusercontent\.com/
      if url =~ /\/s\d+\/[^\/]+$/ or url =~ /\/w\d+-h\d+\/[^\/]+$/ or url =~ /\/w\d+-h\d+-\w+\/[^\/]+$/
        url[0..url[0..(url.rindex('/') - 1)].rindex('/')] + 's0-d' + url[url.rindex('/')..-1]
      elsif url =~ /\/photo.jpg$/ and not url =~ /\/s0-d\/[^\/]+$/
        url[0..url.rindex('/')] + 's0-d' + url[url.rindex('/')..-1]
      else
        url
      end
    else
      url
    end
  end
  
  def self.archive_user(params)
    begin
      raise "Unregistered client." unless client_registered?
    rescue => e
      puts e.message
      return
    end
    
    user_id, compress, delay, output_path, post_limit, quiet, video_downloader =
      (params[:user_id]),
      (params[:compress]),
      (params[:delay] or 0.2),
      (params[:output_path] or FileUtils.pwd),
      (params[:post_limit]),
      (params[:quiet]),
      (params[:video_downloader] or 'you-get')
    
    Dir.mktmpdir do |tmp_dir|
      begin
        response = nil
        
        #>> profile
        puts "##{@@request_num+=1} Fetching people.get ..." unless quiet
        loop do
          begin
            response = @@client.execute(
              :api_method => @@plus.people.get,
              :parameters => {
                'collection' => 'public',
                'userId' => user_id
              },
              :authenticated => false
            )
          rescue
            puts "##{@@request_num} Retrying people.get ..." unless quiet
            next
          else
            break
          end
        end
        
        #<< profile
        File.open("#{tmp_dir}/profile.json", "w") do |f|
          f.puts response.body
        end
        
        user_display_name = JSON.parse(response.body)['displayName']
        
        #>> posts
        if not params[:exclude_posts]
          next_page_token = nil
          page_num = 0
          posts_left = post_limit.to_i
          
          loop do
            puts "##{@@request_num+=1} Fetching activities.list: page[#{page_num}] ..." unless quiet
            if post_limit
              maxResults = (posts_left > 100) ? 100 : posts_left
              posts_left -= maxResults
            else
              maxResults = 100
            end
            loop do
              begin
                response = @@client.execute(
                  :api_method => @@plus.activities.list,
                  :parameters => {
                    'collection' => 'public',
                    'userId' => user_id,
                    'maxResults' => maxResults.to_s,
                    'pageToken' => next_page_token
                  },
                  :authenticated => false
                )
              rescue
                puts "##{@@request_num} Retrying activities.list: page[#{page_num}] ..." unless quiet
                next
              else
                break
              end
            end
            
            activities = JSON.parse(response.body)
            next_page_token = activities['nextPageToken']
            
            #<< posts
            File.open("#{tmp_dir}/posts[#{page_num}].json", "w") do |f|
              f.puts response.body
            end
            
            activities['items'].each do |item|
              activity_id = item['id']
              
              puts "##{@@request_num}   Fetching activities.get: #{activity_id}" unless quiet
              
              #<< post
              File.open("#{tmp_dir}/#{activity_id}.json", "w") do |f|
                f.puts item.to_json
              end
              
              #>> attachments
              if not params[:exclude_attachments] and item['object']['attachments']
                item['object']['attachments'].each do |attachment|
                  if attachment['objectType'] == 'photo'
                    # Download full-size image
                    begin
                      image = attachment['fullImage']
                      image_url = get_full_image_url(image['url'])
                      puts "##{@@request_num}     Fetching attachment: #{image_url} ..." unless quiet
                      uri = URI.parse(URI.escape("#{image_url}"))
                      http = Net::HTTP.new(uri.host, uri.port)
                      if http.port == 443
                        http.use_ssl = true
                        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
                      end
                      data = http.get(uri.request_uri)
                      image_ext = uri.request_uri.split("/")[-1].split(".")[-1]
                      image_ext = nil if image_ext.length > 4
                      
                      #<< attachment
                      File.open("#{tmp_dir}/#{activity_id}_#{attachment['id']}#{image_ext ? ".#{image_ext}" : ""}", "w").puts data.body
                    rescue
                      image = attachment['image']
                      image_url = get_full_image_url(image['url'])
                      puts "##{@@request_num}     Fetching attachment: #{image_url} ..." unless quiet
                      uri = URI.parse(URI.escape("#{image_url}"))
                      http = Net::HTTP.new(uri.host, uri.port)
                      if http.port == 443
                        http.use_ssl = true
                        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
                      end
                      data = http.get(uri.request_uri)
                      image_ext = uri.request_uri.split("/")[-1].split(".")[-1]
                      image_ext = nil if image_ext.length > 4
                      
                      #<< attachment
                      File.open("#{tmp_dir}/#{activity_id}_#{attachment['id']}#{image_ext ? ".#{image_ext}" : ""}", "w").puts data.body
                    end
                    
                  elsif attachment['objectType'] == 'album'
                    # Download full-size thumbnails
                    thumbnails = attachment['thumbnails']
                    if thumbnails
                      thumbnails.each_index do |index|
                        thumbnail = thumbnails[index]
                        image = thumbnail['image']
                        image_url = get_full_image_url(image['url'])
                        puts "##{@@request_num}     Fetching attachment: #{image_url} ..." unless quiet
                        uri = URI.parse(URI.escape("#{image_url}"))
                        http = Net::HTTP.new(uri.host, uri.port)
                        if http.port == 443
                          http.use_ssl = true
                          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
                        end
                        data = http.get(uri.request_uri)
                        image_ext = uri.request_uri.split("/")[-1].split(".")[-1]
                        image_ext = nil if image_ext.length > 4
                        
                        #<< attachment
                        File.open("#{tmp_dir}/#{activity_id}_#{attachment['id']}[#{index}]#{image_ext ? ".#{image_ext}" : ""}", "w").puts data.body
                      end
                    end
                    
                  elsif attachment['objectType'] == 'video'
                    # Download preview image
                    image = attachment['image']
                    image_url = get_full_image_url(image['url'])
                    puts "##{@@request_num}     Fetching attachment: #{image_url} ..." unless quiet
                    uri = URI.parse(URI.escape("#{image_url}"))
                    http = Net::HTTP.new(uri.host, uri.port)
                    if http.port == 443
                      http.use_ssl = true
                      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
                    end
                    data = http.get(uri.request_uri)
                    image_ext = 'gif'
                    
                    #<< attachment
                    File.open("#{tmp_dir}/#{activity_id}_#{attachment['id']}#{image_ext ? ".#{image_ext}" : ""}", "w").puts data.body
                    
                    # Download video
                    puts "##{@@request_num}     Downloading video: #{attachment['url']} ..." unless quiet
                    FileUtils.mkdir("#{tmp_dir}/video")
                    Dir.chdir("#{tmp_dir}/video") do
                      if system("#{video_downloader} #{attachment['url']}")
                        Dir.glob("*").each do |video|
                          FileUtils.mv(video, "#{tmp_dir}/#{activity_id}_#{attachment['id']}_#{attachment['displayName'].split('/').join}.#{video.split('.')[-1]}")
                        end
                      else
                        puts "##{@@request_num}     Video downloader failed. Download aborted."
                      end
                    end
                    FileUtils.rm_r("#{tmp_dir}/video")
                  end
                end
              end
              
              #>> replies
              if not params[:exclude_replies]
                replies_next_page_token = nil
                replies_page_num = 0
                loop do
                  puts "##{@@request_num+=1}     Fetching comments.list: page[#{replies_page_num}] ..." unless quiet
                  loop do
                    begin
                      response = @@client.execute(
                        :api_method => @@plus.comments.list,
                        :parameters => {
                          'activityId' => activity_id,
                          'maxResults' => '500',
                          'pageToken' => replies_next_page_token
                        },
                        :authenticated => false
                      )
                    rescue
                      puts "##{@@request_num}     Retrying comments.list: page[#{replies_page_num}] ..." unless quiet
                      next
                    else
                      break
                    end
                  end
                  
                  replies_next_page_token = JSON.parse(response.body)['nextPageToken']
                  
                  #<< replies
                  File.open("#{tmp_dir}/#{activity_id}_replies#{replies_page_num == 0 && !replies_next_page_token ? "" : "[#{replies_page_num}]"}.json", "w") do |f|
                    f.puts response.body
                  end
                  
                  break unless replies_next_page_token
                  replies_page_num += 1
                  sleep delay
                end
              end
              
              #>> plusoners
              if not params[:exclude_plusoners]
                plusoners_next_page_token = nil
                plusoners_page_num = 0
                loop do
                  puts "##{@@request_num+=1}     Fetching people.listByActivity(plusoners): page[#{plusoners_page_num}] ..." unless quiet
                  loop do
                    begin
                      response = @@client.execute(
                        :api_method => @@plus.people.list_by_activity,
                        :parameters => {
                          'activityId' => activity_id,
                          'collection' => 'plusoners',
                          'maxResults' => '100',
                          'pageToken' => plusoners_next_page_token
                        },
                        :authenticated => false
                      )
                    rescue
                      puts "##{@@request_num}     Retrying people.listByActivity(plusoners): page[#{plusoners_page_num}] ..." unless quiet
                      next
                    else
                      break
                    end
                  end
                  
                  plusoners_next_page_token = JSON.parse(response.body)['nextPageToken']
                  
                  #<< plusoners
                  File.open("#{tmp_dir}/#{activity_id}_plusoners#{plusoners_page_num == 0 && !plusoners_next_page_token ? "" : "[#{plusoners_page_num}]"}.json", "w") do |f|
                    f.puts response.body
                  end
                  
                  break unless plusoners_next_page_token
                  plusoners_page_num += 1
                  sleep delay
                end
              end
              
              #>> resharers
              if not params[:exclude_resharers]
                resharers_next_page_token = nil
                resharers_page_num = 0
                loop do
                  puts "##{@@request_num+=1}     Fetching people.listByActivity(resharers): page[#{resharers_page_num}] ..." unless quiet
                  loop do
                    begin
                      response = @@client.execute(
                        :api_method => @@plus.people.list_by_activity,
                        :parameters => {
                          'activityId' => activity_id,
                          'collection' => 'resharers',
                          'maxResults' => '100',
                          'pageToken' => resharers_next_page_token
                        },
                        :authenticated => false
                      )
                    rescue
                      puts "##{@@request_num}     Retrying people.listByActivity(resharers): page[#{resharers_page_num}] ..." unless quiet
                      next
                    else
                      break
                    end
                  end
                  
                  resharers_next_page_token = JSON.parse(response.body)['nextPageToken']
                  
                  #<< resharers
                  File.open("#{tmp_dir}/#{activity_id}_resharers#{replies_page_num == 0 && !resharers_next_page_token ? "" : "[#{resharers_page_num}]"}.json", "w") do |f|
                    f.puts response.body
                  end
                  
                  break unless resharers_next_page_token
                  resharers_page_num += 1
                  sleep delay
                end
              end
              
            end
            
            break if post_limit and posts_left <= 0
            
            break unless next_page_token
            page_num += 1
            sleep delay
          end
          
        end
        
      rescue Exception => e
        puts e.message
        puts "Archiving interrupted due to unexpected errors."
        
      ensure
        archive_time = "#{Time.now.to_s[0..9]}-#{Time.now.to_s[11..-7]}#{Time.now.to_s[-5..-1]}"
        archive_dest = "#{output_path}/#{user_display_name}_#{archive_time}"
        
        FileUtils.mkdir_p(archive_dest)
        FileUtils.cp_r("#{tmp_dir}/.", archive_dest)
        
        if compress
          begin
            archive_filename = "#{output_path}/#{user_display_name}_#{archive_time}.tar.gz"
            FileUtils.cd(archive_dest) do
              Tempfile.open("#{user_id}") do |tar|
                files = []
                Find.find("./") do |path|
                  files << File.basename(path) unless File.basename(path) == '.'
                end
                Minitar.pack(files, tar)
                
                Zlib::GzipWriter.open(archive_filename) do |gz|
                  gz.mtime = File.mtime(tar.path)
                  gz.orig_name = tar.path
                  gz.write IO.binread(tar.path)
                end
              end
            end
            
            FileUtils.rm_r(archive_dest)
          rescue Exception => e
            puts e.message
            puts "Compression failed."
          end
        end
      end
    end
  end
  
  def self.fetch_post_image(params)
    begin
      raise "Unregistered client." unless client_registered?
    rescue => e
      puts e.message
      return
    end
    
    activity_id, output_path =
      (params[:activity_id]),
      (params[:output_path] or FileUtils.pwd)
    
    response = @@client.execute(
      :api_method => @@plus.activities.get,
      :parameters => {
        'activityId' => activity_id,
        'fields' => 'object/attachments'
      },
      :authenticated => false
    )
    
    attachments = JSON.parse(response.body)['object']['attachments']
    attachments.each do |attachment|
      if attachment['objectType'] == 'photo'
        image = attachment['fullImage']
        image_url = get_full_image_url(image['url'])
        puts "Downloading image: #{image_url} ..."
        uri = URI.parse(URI.escape("#{image_url}"))
        http = Net::HTTP.new(uri.host, uri.port)
        if http.port == 443
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        data = http.get(uri.request_uri)
        
        m = data.header['Content-Disposition'].match(/filename="([^"]+)"/)
        if m
          extname = m[1]
        else
          extname = data.header['Content-Type'].split('/')[-1]
        end
        
        File.open("#{File.join(output_path, activity_id)}.#{extname}", "w").puts data.body
        
      elsif attachment['objectType'] == 'album'
        thumbnails = attachment['thumbnails']
        if thumbnails
          thumbnails.each_index do |index|
            thumbnail = thumbnails[index]
            image = thumbnail['image']
            image_url = get_full_image_url(image['url'])
            puts "Downloading image: #{image_url} ..."
            uri = URI.parse(URI.escape("#{image_url}"))
            http = Net::HTTP.new(uri.host, uri.port)
            if http.port == 443
              http.use_ssl = true
              http.verify_mode = OpenSSL::SSL::VERIFY_NONE
            end
            data = http.get(uri.request_uri)
            
            m = data.header['Content-Disposition'].match(/filename="([^"]+)"/)
            if m
              extname = m[1]
            else
              extname = data.header['Content-Type'].split('/')[-1]
            end
            
            File.open("#{File.join(output_path, activity_id)}[#{index}].#{extname}", "w").puts data.body
          end
        end
      end
    end
  end
  
end
