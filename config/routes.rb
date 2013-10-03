ActionController::Routing::Routes.draw do |map|
  # The priority is based upon order of creation: first created -> highest priority.

  # Sample of regular route:
  #   map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   map.resources :products

  # Sample resource route with options:
  #   map.resources :products, :member => { :short => :get, :toggle => :post }, :collection => { :sold => :get }

  # Sample resource route with sub-resources:
  #   map.resources :products, :has_many => [ :comments, :sales ], :has_one => :seller

  # Sample resource route with more complex sub-resources
  #   map.resources :products do |products|
  #     products.resources :comments
  #     products.resources :sales, :collection => { :recent => :get }
  #   end

  # Sample resource route within a namespace:
  #   map.namespace :admin do |admin|
  #     # Directs /admin/products/* to Admin::ProductsController (app/controllers/admin/products_controller.rb)
  #     admin.resources :products
  #   end

  # You can have the root of your site routed with map.root -- just remember to delete public/index.html.
  map.root :controller => "project"

  # See how all your routes lay out with "rake routes"

  map.connect 'project/create',
      :controller => :project, :action => :create, :conditions => { :method => :post }
  map.connect 'project/delete/:id',
      :controller => :project, :action => :delete, :conditions => { :method => :post }
  map.connect 'project/build/:id',
      :controller => :project, :action => :build, :conditions => { :method => :post }

  map.connect 'project/list/:id', :controller => :project, :action => :list
  map.connect 'project/log/:id', :controller => :project, :action => :log
  map.connect 'project/old_build/:id', :controller => :project, :action => :old_build
  map.connect 'project/show_build/:id', :controller => :project, :action => :show_build
  map.connect 'project/show_bucket/:id', :controller => :project, :action => :show_bucket
  map.connect 'project/index/:id', :controller => :project, :action => :index

  map.connect 'project/:id', :controller => :project, :action => :show

  map.connect 'stats/project/:id', :controller => :stats, :action => :show
end
