# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'viva/version'

Gem::Specification.new do |spec|
  spec.name          = 'viva'
  spec.version       = Viva::VERSION
  spec.authors       = ['Naoki Mizuno']
  spec.email         = ['nigorojr@gmail.com']

  spec.summary       = %q{Stream music}
  spec.description   = %q{Scrape and stream music}
  spec.homepage      = 'https://github.com/NigoroJr/viva'
  spec.license       = 'MIT'

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = ''
  else
    raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.10'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec'

  spec.add_runtime_dependency 'nokogiri'
  spec.add_runtime_dependency 'activerecord'
  spec.add_runtime_dependency 'sqlite3'
  spec.add_runtime_dependency 'levenshtein'
  spec.add_runtime_dependency 'childprocess'
  spec.add_runtime_dependency 'unicode-display_width'
  spec.add_runtime_dependency 'thread'
  spec.add_runtime_dependency 'slop'
  spec.add_runtime_dependency 'ruby-progressbar'
  spec.add_runtime_dependency 'google-search'
end
