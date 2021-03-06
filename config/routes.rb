Rails.application.routes.draw do
  
  resources :rooms
  captcha_route
  get 'static_pages/home'
  get 'static_pages/team'

  devise_for :users
  resources :flies
  resources :crosses
  resources :stocks

  get 'crosses/:id/history' => 'crosses#history'
  get ':id/history' => 'crosses#history'
  get ':id/qr' => 'crosses#qr'
  get '/crosses/:id/qr' => 'crosses#qr'
  get ':id' => 'crosses#show', :as => 'short'
  get ':id/chr' => 'crosses#chromosome'
  get ':id/pnt' => 'crosses#punnett'

  get '/stocks/n/:fly_to_stock' => 'stocks#create'
  get '/stocks/x/add' => 'stocks#add'

  get 'copy/:id' => 'crosses#copy', :as => 'copy'

  root :to => "static_pages#home"

  mathjax 'mathjax'

  # The priority is based upon order of creation: first created -> highest priority.
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
