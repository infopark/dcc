Dcc::Application.routes.draw do
  match '/' => 'project#index'
  match 'project/create' => 'project#create', :via => :post
  match 'project/delete/:id' => 'project#delete', :via => :post
  match 'project/build/:id' => 'project#build', :via => :post
  match 'project/list' => 'project#list'
  match 'project/log/:id' => 'project#log'
  match 'project/old_build/:id' => 'project#old_build'
  match 'project/show_build/:id' => 'project#show_build'
  match 'project/show_bucket/:id' => 'project#show_bucket'
  match 'project/index/:id' => 'project#index'
  match 'project/:id' => 'project#show'
  match 'stats/project/:id' => 'stats#show'
  match 'login' => 'user#login', :as => :login
  match 'logout' => 'user#logout', :as => :logout
  root :to => 'project#index'
end
