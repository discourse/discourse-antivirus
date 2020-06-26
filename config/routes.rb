# frozen_string_literal: true

DiscourseAntivirus::Engine.routes.draw do
  root to: 'antivirus#index'
  get '/stats' => 'antivirus#index'
end
