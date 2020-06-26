# frozen_string_literal: true

module DiscourseAntivirus
  class Engine < ::Rails::Engine
    engine_name 'discourse-antivirus'
    isolate_namespace DiscourseAntivirus

    config.after_initialize do
      Discourse::Application.routes.append do
        mount ::DiscourseAntivirus::Engine, at: '/admin/plugins/antivirus', constraints: AdminConstraint.new
      end
    end
  end
end
