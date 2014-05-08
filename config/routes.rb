Dcc::Application.routes.draw do
  # gui
  get '/' => 'application#index'

  # for gui
  match 'project/create' => 'project#create', :via => :post
  match 'project/delete/:id' => 'project#delete', :via => :post
  match 'project/build/:id' => 'project#build', :via => :post
  get 'project/list' => 'project#list'
  get 'project/log/:id' => 'project#log'
  get 'project/previous_builds/:id' => 'project#previous_builds'
  get 'stats/project/:id' => 'stats#show'

  # classic gui
  get 'classic' => 'project#index'
  get 'project/old_build/:id' => 'project#old_build'
  get 'project/show_build/:id' => 'project#show_build'
  get 'project/show_bucket/:id' => 'project#show_bucket'

  # TODO: noch benötigt? DCC benutzt es nicht. Public-API?
  get 'project/:id' => 'project#show'

  get 'login' => 'user#login', :as => :login
  get 'logout' => 'user#logout', :as => :logout

  root :to => 'application#index'
end
