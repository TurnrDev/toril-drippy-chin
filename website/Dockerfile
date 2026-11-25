# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.3
FROM node:22-trixie-slim AS node
FROM ruby:${RUBY_VERSION}-trixie AS base

# Both targets use the Node major required by iD and the same system libraries.
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/npm
COPY --from=node /opt/yarn-v1.22.22 /opt/yarn-v1.22.22
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
      build-essential ca-certificates curl file git-core libarchive-dev libffi-dev \
      libgd-dev libgeos-dev libpq-dev libsasl2-dev libvips-dev libxml2-dev libxslt1-dev \
      libyaml-dev libatomic1 locales postgresql-client tzdata unzip \
 && rm -rf /var/lib/apt/lists/* \
 && ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
 && ln -s /opt/yarn-v1.22.22/bin/yarn /usr/local/bin/yarn \
 && ln -s /opt/yarn-v1.22.22/bin/yarnpkg /usr/local/bin/yarnpkg
WORKDIR /app

FROM base AS dependencies
ENV BUNDLE_WITHOUT=development:test BUNDLE_FROZEN=true
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 --retry 3
COPY package.json yarn.lock ./
COPY bin/yarn ./bin/yarn
RUN node --version && yarn --version \
 && yarn install --frozen-lockfile --non-interactive
COPY docker/id-imagery.json /tmp/id-imagery.json
RUN cp /tmp/id-imagery.json node_modules/@openstreetmap/id/dist/data/imagery.min.json \
 && cp /tmp/id-imagery.json node_modules/@openstreetmap/id/data/imagery.json \
 && rm /tmp/id-imagery.json

FROM dependencies AS development
# Add test/development gems and browser/import tools to the shared dependencies.
# Compose mounts the source checkout; Xvfb remains available for browser tests.
ENV BUNDLE_WITHOUT="" BUNDLE_FROZEN=false
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
      default-jre-headless gpg-agent osmosis firefox-esr xvfb mesa-utils libgl1-mesa-dri \
 && rm -rf /var/lib/apt/lists/* \
 && bundle install --jobs 4 --retry 3
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# The default build is the self-contained production image; Compose selects development.
FROM dependencies AS production
ENV RAILS_ENV=production \
    BOOTSNAP_CACHE_DIR=/tmp/bootsnap \
    DND_MAP_STORAGE_DIR=/app/storage \
    DND_MAP_PAGE_CACHE_DIR=/app/tmp/page-cache

COPY . .
RUN cp config/example.storage.yml config/storage.yml \
 && printf '%s\n' 'production:' '  url: <%= ENV.fetch("DATABASE_URL") %>' \
      '  pool: <%= ENV.fetch("RAILS_MAX_THREADS", 3) %>' > config/database.yml \
 && printf '{}\n' > config/settings.local.yml \
 && SECRET_KEY_BASE_DUMMY=1 DATABASE_URL=postgresql://localhost:1/dnd_map_build \
      bundle exec i18n export \
 && SECRET_KEY_BASE_DUMMY=1 DATABASE_URL=postgresql://localhost:1/dnd_map_build \
      bundle exec rails assets:precompile \
 && test -s public/assets/manifest.json \
 && rm -rf tmp/cache /tmp/bootsnap \
 && mkdir -p storage tmp/page-cache

EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "--binding", "0.0.0.0", "--port", "3000"]
