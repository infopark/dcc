Rails.application.routes.draw do
  # gui
  get '/' => 'application#index'

  # for gui
  post 'project/create' => 'project#create'
  post 'project/delete/:id' => 'project#delete'
  post 'project/build/:id' => 'project#build'
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

  match 'login' => 'user#login', :as => :login, :via => [:post, :get]
  get 'logout' => 'user#logout', :as => :logout

  root :to => 'application#index'

  # examples provided by Rails:
  # The priority is based upon order of creation: first created -> highest priority
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
