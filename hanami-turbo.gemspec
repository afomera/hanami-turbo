# frozen_string_literal: true

require_relative "lib/hanami/turbo/version"

Gem::Specification.new do |spec|
  spec.name = "hanami-turbo"
  spec.version = Hanami::Turbo::VERSION
  spec.authors = ["Andrea Fomera"]
  spec.email = ["afomera@hey.com"]
  spec.summary = "Hotwire Turbo support for Hanami apps"
  spec.description = "Turbo Stream rendering, Turbo Frame helpers, and Turbo-friendly redirects for Hanami"
  spec.homepage = "https://hanamirb.org"
  spec.license = "MIT"

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 3.3"

  spec.add_dependency "hanami", ">= 2.3"
  spec.add_dependency "hanami-action", ">= 2.3"
  spec.add_dependency "hanami-view", ">= 2.3"
end
