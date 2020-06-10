# frozen_string_literal: true
module DiscourseAntivirus
  class Engine < ::Rails::Engine
    engine_name "DiscourseAntivirus".freeze
    isolate_namespace DiscourseAntivirus

    config.after_initialize do
      Discourse::Application.routes.append do
        mount ::DiscourseAntivirus::Engine, at: "/discourse-antivirus"
      end
    end
  end
end
