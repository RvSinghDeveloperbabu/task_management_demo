Rails.application.routes.draw do
  # Kubernetes probes
  get "/health", to: "health#live"    # liveness: process is up
  get "/ready",  to: "health#ready"   # readiness: Postgres + Redis reachable

  scope "/api" do
    get "/info", to: "info#show"
    resources :tasks, only: %i[index create destroy]
  end
end
