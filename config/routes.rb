Dcc::Application.routes.draw do
  # gui
  match '/' => 'application#index'

  # for gui
  match 'project/create' => 'project#create', :via => :post
  match 'project/delete/:id' => 'project#delete', :via => :post
  match 'project/build/:id' => 'project#build', :via => :post
  match 'project/list' => 'project#list'
  match 'project/log/:id' => 'project#log'
  match 'project/previous_builds/:id' => 'project#previous_builds'
  match 'stats/project/:id' => 'stats#show'

  # classic gui
  match 'classic' => 'project#index'
  match 'project/old_build/:id' => 'project#old_build'
  match 'project/show_build/:id' => 'project#show_build'
  match 'project/show_bucket/:id' => 'project#show_bucket'

  # TODO: noch benötigt? DCC benutzt es nicht. Public-API?
  match 'project/:id' => 'project#show'

  match 'login' => 'user#login', :as => :login
  match 'logout' => 'user#logout', :as => :logout

  root :to => 'application#index'
end
