Gem::Specification.new do |spec|
  spec.name = "users"
  spec.version = "0.1.0"
  spec.authors = [ "meetings-app" ]
  spec.summary = "User accounts: creation, lookup, and password authentication."
  spec.files = Dir["lib/**/*.rb", "app/**/*.rb"]
  spec.require_paths = [ "lib" ]
  spec.required_ruby_version = ">= 3.2"

  spec.add_dependency "bcrypt", "~> 3.1"
  spec.add_dependency "cqrs"
  spec.add_dependency "rails", "~> 8.1"
end
