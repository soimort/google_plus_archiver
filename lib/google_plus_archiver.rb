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
    @@client = Google::APIClient.new
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
  
  def self.archive_user(params)
    begin
      raise "Unregistered client." unless client_registered?
    rescue => e
      puts e.message
      return
    end
    
    user_id, delay, output_path, quiet =
      (params[:user_id]),
      (params[:delay] or 0.2),
      (params[:output_path] or FileUtils.pwd),
      (params[:quiet])
    
    Dir.mktmpdir do |tmp_dir|
      
      begin
        
        #>> profile
        puts "##{@@request_num+=1} Fetching people.get ..." unless quiet
        response = @@client.execute(
          :api_method => @@plus.people.get,
          :parameters => {
            'collection' => 'public',
            'userId' => user_id
          },
          :authenticated => false
        )
        
        #<< profile
        File.open("#{tmp_dir}/profile.json", "w") do |f|
          f.puts response.body
        end
        
        user_display_name = JSON.parse(response.body)['displayName']
        
        #>> posts
        if not params[:exclude_posts]
          next_page_token = nil
          page_num = 0
          loop do
            puts "##{@@request_num+=1} Fetching activities.list: page[#{page_num}] ..." unless quiet
            response = @@client.execute(
              :api_method => @@plus.activities.list,
              :parameters => {
                'collection' => 'public',
                'userId' => user_id,
                'maxResults' => '100',
                'pageToken' => next_page_token
              },
              :authenticated => false
            )
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
                  image = (attachment['fullImage'] or attachment['image'])
                  if image
                    puts "##{@@request_num}     Fetching attachment: #{image['url']} ..." unless quiet
                    uri = URI.parse(URI.escape("#{image['url']}"))
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
                  
                  thumbnails = attachment['thumbnails']
                  if thumbnails
                    thumbnails.each_index do |index|
                      thumbnail = thumbnails[index]
                      image = thumbnail['image']
                      puts "##{@@request_num}     Fetching attachment(thumbnail): #{image['url']} ..." unless quiet
                      uri = URI.parse(URI.escape("#{image['url']}"))
                      http = Net::HTTP.new(uri.host, uri.port)
                      if http.port == 443
                        http.use_ssl = true
                        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
                      end
                      data = http.get(uri.request_uri)
                      image_ext = uri.request_uri.split("/")[-1].split(".")[-1]
                      image_ext = nil if image_ext.length > 4
                      
                      #<< attachment
                      File.open("#{tmp_dir}/#{activity_id}_#{attachment['id']}_#{index.to_s}#{image_ext ? ".#{image_ext}" : ""}", "w").puts data.body
                    end
                  end
                end
              end
              
              #>> replies
              if not params[:exclude_replies]
                replies_next_page_token = nil
                replies_page_num = 0
                loop do
                  puts "##{@@request_num+=1}     Fetching comments.list: page[#{replies_page_num}] ..." unless quiet
                  response = @@client.execute(
                    :api_method => @@plus.comments.list,
                    :parameters => {
                      'activityId' => activity_id,
                      'maxResults' => '500',
                      'pageToken' => replies_next_page_token
                    },
                    :authenticated => false
                  )
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
            
            break unless next_page_token
            page_num += 1
            sleep delay
          end
          
        end
        
      rescue Exception => e
        puts e.message
        puts "Archiving interrupted due to unexpected errors."
        
      ensure
        # Archive all the files
        archive_time = "#{Time.now.to_s[0..9]}-#{Time.now.to_s[11..-7]}#{Time.now.to_s[-5..-1]}"
        archive_filename = "#{output_path}/#{user_display_name}_#{archive_time}.tar.gz"
        FileUtils.cd(tmp_dir) do
          
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
        
      end
      
    end
    
  end
  
end
