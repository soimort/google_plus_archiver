
GEMSPEC = eval(File.read(Dir["*.gemspec"][0]))

task :default => [:test]

task :build do
  sh "gem build #{GEMSPEC.name}.gemspec"
end

task :install => :build do
  sh "gem install #{GEMSPEC.name}-#{GEMSPEC.version}.gem"
end

require 'rake/testtask'
Rake::TestTask.new do |test|
  test.libs << 'test'
end
