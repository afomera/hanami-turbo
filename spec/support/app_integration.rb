# frozen_string_literal: true

require "hanami/devtools/integration/files"
require "hanami/devtools/integration/with_tmp_directory"
require "rack/test"
require "tmpdir"

# Boots throwaway Hanami apps in tmp directories, adapted from hanami's own integration specs.
module AppIntegration
  APP_MODULES = %i[TestApp Main].freeze

  # Writes the boilerplate every integration example needs: an app, base action/view, a layout,
  # and an app config that installs Turbo.
  def write_app(app_config: "Hanami::Turbo.install(config)", layout: "<html><body><%= yield %></body></html>\n")
    write "config/app.rb", <<~RUBY
      require "hanami"
      require "hanami/turbo"

      module TestApp
        class App < Hanami::App
          config.logger.stream = File::NULL
          #{app_config}
        end
      end
    RUBY

    write "app/action.rb", <<~RUBY
      # auto_register: false

      module TestApp
        class Action < Hanami::Action
        end
      end
    RUBY

    write "app/view.rb", <<~RUBY
      # auto_register: false

      require "hanami/view"

      module TestApp
        class View < Hanami::View
        end
      end
    RUBY

    # Pass the layout here rather than overwriting it later: devtools' `write` doesn't truncate.
    write "app/templates/layouts/app.html.erb", layout
  end

  def boot_app
    require "hanami/prepare"
    Hanami.app
  end
end

RSpec.configure do |config|
  config.include RSpec::Support::Files, :app_integration
  config.include RSpec::Support::WithTmpDirectory, :app_integration
  config.include AppIntegration, :app_integration

  config.around :each, :app_integration do |example|
    load_paths = $LOAD_PATH.dup
    loaded_features = $LOADED_FEATURES.dup

    with_tmp_directory(Dir.mktmpdir) { example.run }
  ensure
    Hanami::Slice.subclasses.flat_map { |s| [s, *s.subclasses] }.each do |slice|
      slice.autoloader.unregister if slice.instance_variable_defined?(:@autoloader)
    end
    Hanami.instance_variable_set(:@_bundled, {})
    Hanami.remove_instance_variable(:@_app) if Hanami.instance_variable_defined?(:@_app)

    $LOAD_PATH.replace(load_paths)
    $LOADED_FEATURES.replace(
      loaded_features + ($LOADED_FEATURES - loaded_features).reject { |path|
        path =~ %r{hanami/(setup|prepare|boot)} || path.include?(Dir.tmpdir) || path.include?("/private/var/")
      }
    )

    AppIntegration::APP_MODULES.each do |name|
      Object.send(:remove_const, name) if Object.const_defined?(name)
    end
  end
end

# Helpers for writing actions and views and calling them like Turbo does.
module AppIntegration
  TURBO_STREAM_ACCEPT = "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
  HTML_ACCEPT = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"

  # Writes `actions/<name>.rb` and `views/<name>.rb`, e.g. `write_action("books/create")`.
  def write_action(name, handle: nil, view_body: nil)
    parts = name.split("/")
    modules = parts.map { |part| part.split("_").map(&:capitalize).join }
    *namespaces, klass = modules

    write "app/actions/#{name}.rb", <<~RUBY
      module TestApp
        module Actions
          #{namespaces.map { |ns| "module #{ns}" }.join("; ")}
            class #{klass} < TestApp::Action
              #{"def handle(req, res)\n#{handle}\nend" if handle}
            end
          #{namespaces.map { "end" }.join("; ")}
        end
      end
    RUBY

    write "app/views/#{name}.rb", <<~RUBY
      module TestApp
        module Views
          #{namespaces.map { |ns| "module #{ns}" }.join("; ")}
            class #{klass} < TestApp::View
              #{view_body}
            end
          #{namespaces.map { "end" }.join("; ")}
        end
      end
    RUBY
  end

  def call_action(name, method: "GET", accept: HTML_ACCEPT, headers: {}, params: {})
    env = {
      "REQUEST_METHOD" => method,
      "HTTP_ACCEPT" => accept,
      "rack.input" => StringIO.new,
      **headers
    }
    TestApp::App["actions.#{name.tr("/", ".")}"].call(env.merge(params))
  end

  def body_of(response)
    response.body.join
  end
end
