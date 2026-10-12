# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# Built against the main branches of Hanami and its gems.
gem "hanami", github: "hanami/hanami", branch: "main"
gem "hanami-utils", github: "hanami/hanami-utils", branch: "main"
gem "hanami-router", github: "hanami/hanami-router", branch: "main"
gem "hanami-action", github: "hanami/hanami-action", branch: "main"
gem "hanami-view", github: "hanami/hanami-view", branch: "main"
gem "hanami-cli", github: "hanami/hanami-cli", branch: "main"
gem "hanami-devtools", github: "hanami/devtools", branch: "main"
gem "dry-system", github: "dry-rb/dry-system", branch: "main"
gem "dry-cli", github: "dry-rb/dry-cli", branch: "main"

gem "rake", ">= 12.3.3"

group :test do
  gem "rack-test"
  gem "rspec", "~> 3.13"
end

group :tools do
  gem "rubocop"
end
