Gem::Specification.new do |spec|
  spec.name         = "nakischema"
  spec.version      = "0.3.0"
  spec.summary      = "compact yet powerful arbitrary nested objects validator"
  spec.description  = "The most compact yet powerful arbitrary nested objects validator. Especially handy to validate JSONs."

  spec.author       = "Victor Maslov aka Nakilon"
  spec.email        = "nakilon@gmail.com"
  spec.license      = "MIT"
  spec.metadata     = {"source_code_uri" => "https://github.com/nakilon/nakischema"}

  spec.add_dependency "regexp-examples"
  spec.add_dependency "addressable"

  spec.files        = %w{ LICENSE nakischema.gemspec lib/nakischema.rb }
end
