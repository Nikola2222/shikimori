# Используем официальный образ Ruby
FROM ruby:3.2.6 AS base

WORKDIR /shikimori

# Install base packages

RUN apt-get update -qq && \
    apt-get install -y curl gnupg2 postgresql-client locales imagemagick libjpeg-turbo-progs && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives && \
    sed -i 's/# ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen

# Install JavaScript dependencies and Node.js for asset compilation

ARG NODE_VERSION=22.2.0
ARG YARN_VERSION=1.22.19
ENV PATH=/usr/local/node/bin:$PATH
RUN curl -sL https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \
    /tmp/node-build-master/bin/node-build "${NODE_VERSION}" /usr/local/node && \
    npm install -g yarn && \
    # npm install -g mjml && \
    rm -rf /tmp/node-build-master

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LANG="ru_RU.UTF-8" \
    LC_ALL="ru_RU.UTF-8"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential curl git pkg-config libyaml-dev && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives


# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Install node modules
COPY package.json yarn.lock ./
RUN --mount=type=cache,id=yarn,target=/shikimori/.cache/yarn YARN_CACHE_FOLDER=/shikimori/.cache/yarn \
    yarn install --frozen-lockfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
# RUN bundle exec bootsnap precompile app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN bundle exec rails assets:precompile

# Final stage for app image
FROM base

# Copy built artifacts: gems, application
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /shikimori /shikimori

# Run and own only the runtime files as a non-root user for security
# RUN groupadd --system --gid 1000 shikimori && \
#     useradd shikimori --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
#     chown -R shikimori:shikimori db log public tmp

RUN chmod u+x /shikimori/bin/docker-entrypoint
# USER 1000:1000

# Entrypoint prepares the database.
ENTRYPOINT ["/shikimori/bin/docker-entrypoint"]

# Start the application server
EXPOSE 3000
CMD ["./bin/rails", "server"]
