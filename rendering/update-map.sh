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

echo "Rebuilding water polygons from OSM land data..."

docker compose exec -T db psql \
  -U openstreetmap \
  -d rendering \
  -v ON_ERROR_STOP=1 \
  <<'SQL'
BEGIN;

DROP TABLE IF EXISTS water_polygons_new;
DROP TABLE IF EXISTS simplified_water_polygons_new;

CREATE TABLE water_polygons_new AS
WITH land AS (
    SELECT ST_UnaryUnion(ST_Collect(way)) AS geom
    FROM planet_osm_polygon
    WHERE "natural" = 'land'
),
world AS (
    SELECT ST_MakeEnvelope(
        -20037508.342789244,
        -20037508.342789244,
         20037508.342789244,
         20037508.342789244,
         3857
    ) AS geom
)
SELECT
    ST_Multi(
        ST_Difference(world.geom, land.geom)
    )::geometry(MultiPolygon, 3857) AS way
FROM world, land
WHERE land.geom IS NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM water_polygons_new
        WHERE way IS NOT NULL
          AND NOT ST_IsEmpty(way)
    ) THEN
        RAISE EXCEPTION 'No valid water polygon generated from OSM land data';
    END IF;
END
$$;

CREATE TABLE simplified_water_polygons_new AS
SELECT
    ST_Multi(
        ST_SimplifyPreserveTopology(way, 5000)
    )::geometry(MultiPolygon, 3857) AS way
FROM water_polygons_new;

DROP TABLE IF EXISTS water_polygons;
ALTER TABLE water_polygons_new
    RENAME TO water_polygons;

DROP TABLE IF EXISTS simplified_water_polygons;
ALTER TABLE simplified_water_polygons_new
    RENAME TO simplified_water_polygons;

CREATE INDEX water_polygons_way_idx
    ON water_polygons
    USING GIST (way);

CREATE INDEX simplified_water_polygons_way_idx
    ON simplified_water_polygons
    USING GIST (way);

COMMIT;

ANALYZE water_polygons;
ANALYZE simplified_water_polygons;
SQL

echo "Water polygons rebuilt."

echo "Clearing rendered tile cache..."

docker compose exec -T renderer \
  sh -c 'rm -rf /var/cache/renderd/tiles/*'

echo "Rendering database updated."
