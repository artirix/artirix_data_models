# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'artirix_data_models/version'

Gem::Specification.new do |spec|
  spec.name          = "artirix_data_models"
  spec.version       = ArtirixDataModels::VERSION
  spec.authors       = ["Eduardo Turiño"]
  spec.email         = ["eturino@artirix.com"]
  spec.summary       = "Data Models (read only model) and Data Layer connection lib"
  spec.description   = %q{used in Boat International UI and Admin apps}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'activesupport'
  spec.add_dependency 'simple_config'
  spec.add_dependency 'oj'
  spec.add_dependency 'faraday'
  spec.add_dependency 'kaminari'

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end
