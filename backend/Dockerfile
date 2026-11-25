# One image, three roles (change the command):
#   web      -> bundle exec puma -C config/puma.rb      (default)
#   worker   -> bundle exec sidekiq -C config/sidekiq.yml
#   migrate  -> bundle exec rails db:prepare            (Job / initContainer)
FROM ruby:3.3-slim

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends build-essential libpq-dev curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV RAILS_ENV=production \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_DEPLOYMENT=0

COPY Gemfile Gemfile.lock* ./
RUN bundle install --jobs 4 && rm -rf ~/.bundle/cache

COPY . .

# Run as non-root (required by many Kubernetes security policies)
RUN useradd --create-home --uid 1000 rails && \
    mkdir -p tmp log && chown -R rails:rails /app
USER 1000

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
