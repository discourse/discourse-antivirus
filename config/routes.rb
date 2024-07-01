# frozen_string_literal: true

Discourse::Application.routes.draw do
  scope "/admin/plugins/discourse-antivirus", constraints: AdminConstraint.new do
    get "/stats" => "discourse_antivirus/admin/antivirus#index"
  end
end
