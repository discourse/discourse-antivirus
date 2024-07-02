# frozen_string_literal: true

module ::DiscourseAntivirus
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseAntivirus
    config.autoload_paths << File.join(config.root, "lib")
  end
end
