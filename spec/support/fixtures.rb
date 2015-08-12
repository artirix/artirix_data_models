require 'pathname'

def fixture_pathname(filename)
  Pathname(__FILE__).join("../../fixtures/#{filename}")
end