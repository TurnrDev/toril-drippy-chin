# Production images

The root `.github/workflows/images.yml` builds and checks three amd64 images.
Pull requests build without publishing. Pushes to `main`, or a manual workflow
run on `main`, publish successful images to GHCR:

| Image | Contents |
| --- | --- |
| `ghcr.io/turnrdev/toril-drippy-chin-web:latest` | Rails, production assets and background-job dependencies |
| `ghcr.io/turnrdev/toril-drippy-chin-renderer:latest` | Apache, renderd, configuration and the checked-out Carto style |
| `ghcr.io/turnrdev/toril-drippy-chin-db:latest` | Existing PostgreSQL 14/PostGIS Dockerfile and initialization script |

The web checks verify native gem loading, compiled assets, and clean SIGTERM
shutdown through the Rails launcher using a tiny Rack app. Puma disables its
post-shutdown signal exception so intentional stops return success.

Each image also receives `sha-<full-commit>` and OCI source/revision/version labels.
CI authenticates using GitHub's built-in token; no repository token secret is needed.
New GHCR packages may need their visibility set to public for anonymous server pulls.

The web build uses Ruby 3.3, Node 22 and the existing Gemfile.lock/yarn.lock.
Node and Yarn come from the official Node image, rather than Debian's Node 20. Assets compile
without a live database or production secrets. Unlike the development image, it
contains the application: do not mount the source tree, node_modules or public/assets.
`website/Dockerfile` shares system libraries, Node/Yarn, production gems and
JavaScript dependencies between two targets. `production` (the default and CI
target) includes source/assets. `development` adds the remaining gem groups,
browser/import tools and the Xvfb entrypoint; root Compose selects it explicitly
and keeps the source bind mount. Production does not inherit those dev tools.

## Runtime configuration

Supply these settings at deployment:

| Setting | Purpose |
| --- | --- |
| `DATABASE_URL` | Existing PostgreSQL database connection |
| `SECRET_KEY_BASE_FILE` | Stable production secret mounted as a runtime file |
| `DND_MAP_SETTINGS_FILE` | Runtime YAML overrides, preserving OAuth application identities |
| `DND_MAP_STORAGE_DIR` | Retained uploads; default `/app/storage` |
| `DND_MAP_PAGE_CACHE_DIR` | Writable page cache; default `/app/tmp/page-cache` |

Mount retained uploads at `/app/storage`, scratch data at `/data`, and provide
writable `/app/tmp`. The default command starts Rails on port 3000. Use the same
web image with `bundle exec rails jobs:work` for the production queue, and run
`bundle exec rails db:migrate` as a separate deployment step.

Browser-visible settings are compiled from tracked `website/config/settings.yml`;
changing server URLs in runtime overrides does not rewrite the compiled JavaScript.
Keep public build settings consistent with the deployment. Private local YAML,
credentials and mutable data are excluded from the Docker build context.

The renderer includes source configuration and style files; mount only imagery,
scratch data and writable tile caches. Its database hostname remains `db`.
Keep that network alias when deploying with OCI.

Publishing a new database image does not establish retained-data compatibility.
Before using it with the live database directory, verify PostgreSQL/PostGIS versions,
base OS and collation compatibility. No database upgrade is part of this change.

## Local build (optional)

```sh
docker build --target production -t dnd-map-web:local website
```

For the source-mounted development setup, use `docker compose build rails`
from the repository root. Normal deployment uses the CI-published images
through NixOS OCI containers.
