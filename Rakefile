require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

require 'artirix_gem_release' if ENV['ARTIRIX_GEM_SERVER']

RSpec::Core::RakeTask.new(:spec)

task default: :spec
