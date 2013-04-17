require File.expand_path('../lib/detention_data/version', __FILE__)

Gem::Specification.new do |s|
  s.name = %q{detention_data}
  s.version = DetentionData::VERSION
  s.authors = ["B.J. Rossiter"]
  s.date = Time.now.utc.strftime("%Y-%m-%d")
  s.email = %q{b.j.rossiter@gmail.com}
  s.files = `git ls-files`.split("\n")
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{Importer for Detention Incident Data}
  s.add_development_dependency 'rspec'
  s.add_dependency 'mechanize'
end
