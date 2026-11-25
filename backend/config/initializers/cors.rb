# Only needed when the React dev server (different origin) calls the API directly.
# In docker-compose / Kubernetes the frontend's nginx proxies /api, so it is same-origin.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("CORS_ORIGINS", "http://localhost:5173,http://localhost:8080").split(",").map(&:strip)
    resource "/api/*", headers: :any, methods: %i[get post delete options head]
  end
end
