# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'artirix_data_models/version'

Gem::Specification.new do |spec|
  spec.name          = 'artirix_data_models'
  spec.version       = ArtirixDataModels::VERSION
  spec.authors       = ['Eduardo Turiño']
  spec.email         = ['eturino@artirix.com']
  spec.summary       = 'Data Models (read only model) and Data Layer connection lib'
  spec.description   = %q{used in Boat International UI and Admin apps}
  spec.homepage      = ''
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'activesupport'
  spec.add_dependency 'activemodel'
  spec.add_dependency 'oj'
  spec.add_dependency 'faraday'
  spec.add_dependency 'keyword_init', '~> 1.4'
  spec.add_dependency 'naught'
  spec.add_dependency 'artirix_cache_service'

  spec.add_development_dependency 'simpleconfig'

  spec.add_development_dependency 'kaminari', '~> 0.16'
  spec.add_development_dependency 'will_paginate', '~> 3.0'

  spec.add_development_dependency 'bundler', '>= 1.10'
  spec.add_development_dependency 'rake', '>= 10.0'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rspec-given'
  spec.add_development_dependency 'faker'
end
