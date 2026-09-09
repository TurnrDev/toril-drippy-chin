#!/usr/bin/env bash
set -euo pipefail

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

echo "Rendering database updated."
