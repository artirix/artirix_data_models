source 'https://rubygems.org'

artirix_gem_server = ENV.fetch('ARTIRIX_GEM_SERVER') do
  puts "NO access to ARTIRIX GEM SERVER (use ARTIRIX_GEM_SERVER env variable)"
  nil
end

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

if artirix_gem_server
  gem 'artirix_gem_release', '0.0.17', group: [:development, :test], source: artirix_gem_server
end
