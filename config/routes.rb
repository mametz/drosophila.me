Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[new create]
  resource :account, only: %i[edit update destroy]

  # Devise paths people may have bookmarked
  get "/users/sign_in", to: redirect("/session/new")
  get "/users/sign_up", to: redirect("/registration/new")

  get "static_pages/home", to: redirect("/")
  get "static_pages/team", to: "static_pages#team", as: :team

  resources :rooms, except: :show
  resources :stocks
  post "stocks/n/:fly_id", to: "stocks#from_fly", as: :stock_from_fly

  post "copy/:id", to: "crosses#copy", as: :copy_cross
  resources :crosses, only: %i[index new create update destroy]

  get "up" => "rails/health#show", as: :rails_health_check

  root "static_pages#home"

  # Short links are printed on labels as QR codes, so these paths must not change.
  get "crosses/:id", to: "crosses#show"
  get "crosses/:id/history", to: "crosses#history"
  get "crosses/:id/qr", to: "crosses#qr"
  get ":id", to: "crosses#show", as: :short
  get ":id/history", to: "crosses#history", as: :history
  get ":id/qr", to: "crosses#qr", as: :qr
  get ":id/chr", to: "crosses#chromosome", as: :chromosome
  get ":id/rec", to: "crosses#recombinants", as: :recombinants
  get ":id/pnt", to: "crosses#punnett", as: :punnett
end
