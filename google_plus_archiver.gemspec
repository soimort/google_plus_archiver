require File.expand_path('../lib/google_plus_archiver/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = "google_plus_archiver"
  s.version     = GooglePlusArchiver::VERSION
  s.date        = GooglePlusArchiver::DATE
  s.summary     = "A simple command-line tool to archive Google+ profiles."
  s.description = "google_plus_archiver is a simple command-line tool to archive Google+ profiles and public streams."
  s.license     = "MIT"
  
  s.homepage    = "https://github.com/soimort/google_plus_archiver"
  
  s.authors     = ["Mort Yao"]
  s.email       = "mort.yao@gmail.com"
  
  s.add_runtime_dependency("google-api-client", "~> 0.5")
  s.add_runtime_dependency("archive-tar-minitar", "~> 0.5")
  
  s.executables = ["gplus-get"]
  
  # = MANIFEST =
  s.files       = %w[
    bin/gplus-get
    lib/google_plus_archiver.rb
    lib/google_plus_archiver/version.rb
  ]
  # = MANIFEST =
end
