# frozen_string_literal: true

# Enables secure cross-origin requests for the API responses.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'http://localhost:3000', 'https://your-app.vercel.app'

    resource '/api/*',
             headers: :any,
             methods: %i[get post put patch delete options head],
             credentials: false,
             max_age: 600
  end
end
