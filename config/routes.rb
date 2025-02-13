Rails.application.routes.draw do
  resources :images do
    collection do
      post :bulk_process
    end
  end
  root 'images#index'
end
