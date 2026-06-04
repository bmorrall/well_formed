# frozen_string_literal: true

Rails.application.routes.draw do
  namespace :api do
    resources :users, only: [:create]
    resources :posts, only: [:create, :update]
    resources :articles, only: [:create, :update] do
      scope module: :articles do
        resource :publication, only: [:create, :update]
      end
    end
    resource :user_profile, only: [:update]
    resource :subscription, only: [:create]
    resources :orders, only: [:create, :update]
    resources :flat_orders, only: [:create, :update]
  end
  resources :posts, only: [:new, :create, :edit, :update] do
    scope module: :posts do
      resource :publication, only: [:create, :update]
    end
  end
  resource :subscription, only: [:new, :create]
  resources :orders, only: [:show, :new, :create, :edit, :update]
  namespace :simple_form do
    resources :orders, only: [:new, :create, :edit, :update]
    resources :posts, only: [:new, :create, :edit, :update]
  end
end
