lib = File.join(File.dirname(__FILE__), 'lib')
$:.unshift lib unless $:.include?(lib)

require 'llama/version'

Gem::Specification.new do |s|
  s.name        = 'llama'
  s.version     = Llama::VERSION
  s.licenses    = ['GPL']
  s.summary     = 'A simple bot framework'
  s.description = "A simple bot framework"
  s.authors     = ["SuHun Han (ssut)"]
  s.email       = 'ssut@ssut.me'
  s.files       = ['LICENSE', '{lib}/**/*']
  s.homepage    = 'https://github.com/ssut/llama'
end
