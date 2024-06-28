# frozen_string_literal: true

#DiscourseAntivirus::Engine.routes.draw do
#  root to: "antivirus#index"
#  get "/stats" => "antivirus#index"
#end

Discourse::Application.routes.draw do
  scope "/admin/plugins/antivirus", constraints: AdminConstraint.new do
    get "/stats" => "antivirus#index"
  end
end
