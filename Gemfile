source 'https://rubygems.org'

# Specify your gem's dependencies in artirix_data_models.gemspec
gemspec

group :development, :test do
  gem 'pry'
  gem 'pry-nav'
  gem 'pry-stack_explorer'
  gem 'pry-doc'
  gem 'pry-rescue'
end

group :test do
  gem 'fakeredis', require: "fakeredis/rspec"
end

artirix_gem_server = ENV.fetch('ARTIRIX_GEM_SERVER') do
  raise "NO access to ARTIRIX GEM SERVER (use ARTIRIX_GEM_SERVER env variable)"
end

source artirix_gem_server do
  gem 'artirix_gem_release', '0.0.17', group: [:development, :test]
end
