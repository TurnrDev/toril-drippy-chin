#!/usr/bin/env bash
set -euo pipefail

exec 9>/tmp/dnd-map-update.lock
flock -n 9 || exit 0

echo "Exporting OSM data from Rails..."

docker compose exec -T rails \
  osmosis \
    --read-apidb \
      host="db" \
      database="openstreetmap" \
      user="openstreetmap" \
      password="openstreetmap" \
      validateSchemaVersion=no \
    --write-xml file="/data/toril.osm"

echo "Importing into rendering database..."

docker compose exec -T renderer \
  osm2pgsql \
    -O flex \
    -S /openstreetmap-carto/openstreetmap-carto-flex.lua \
    -d rendering \
    -H db \
    -U openstreetmap \
    /data/toril.osm

echo "Clearing rendered tile cache..."

docker compose exec -T renderer \
  sh -c 'rm -rf /var/cache/renderd/tiles/*'

echo "Rendering database updated."
