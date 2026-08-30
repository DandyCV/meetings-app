Gem::Specification.new do |spec|
  spec.name = "auth"
  spec.version = "0.1.0"
  spec.authors = [ "meetings-app" ]
  spec.summary = "Token generation and verification for API authentication."
  spec.files = Dir["lib/**/*.rb", "app/**/*.rb"]
  spec.require_paths = [ "lib" ]
  spec.required_ruby_version = ">= 3.2"

  spec.add_dependency "cqrs"
  spec.add_dependency "jwt"
  spec.add_dependency "rails", "~> 8.1"
end
