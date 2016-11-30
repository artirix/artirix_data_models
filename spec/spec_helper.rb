$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'bundler/setup'
Bundler.setup

require 'simplecov'
SimpleCov.start

require 'rspec/given'


require 'pry'
require 'artirix_data_models'

Pathname.glob(Pathname(__FILE__).dirname + 'support/**/*.rb').each { |f| require f }

RSpec.configure do |config|
  # some (optional) config here
end
