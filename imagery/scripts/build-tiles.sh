#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SOURCE_DIR="${ROOT_DIR}/source"
BUILD_DIR="${ROOT_DIR}/build"
BUILD_4326="${BUILD_DIR}/4326"
BUILD_3857="${BUILD_DIR}/3857"
BUILD_VRT="${BUILD_DIR}/vrt"
TILES_DIR="${ROOT_DIR}/tiles"
COMBINED_TILES_DIR="${TILES_DIR}/combined"

TORIL_SOURCE="${SOURCE_DIR}/AIF (2023) - Toril.png"
FAERUN_SOURCE="${SOURCE_DIR}/AIF (2020) - Faerun_v2.jpg"
MURANN_SOURCE="${SOURCE_DIR}/Morann.png"

PROCESSES="${PROCESSES:-$(nproc)}"

MERCATOR_MAX_LAT="85.05112878"

MURANN_CENTRE_LON="-70.3763"
MURANN_CENTRE_LAT="30.9625"

# Murann scale established from the building-size calibration.
MURANN_METRES_PER_PIXEL="0.4836"

# EPSG:4326 bounds calculated to preserve 0.4836 m/px around
# the fixed Murann centre at WGS84 latitude 30.9625.
MURANN_LEFT="-70.3825764692"
MURANN_TOP="30.9701507931"
MURANN_RIGHT="-70.3700235308"
MURANN_BOTTOM="30.9548492069"

# Return an XYZ-tile-aligned EPSG:3857 extent and pixel resolution for the
# tiles intersecting a raster at a particular zoom level.
#
# Output: min_x min_y max_x max_y resolution
xyz_aligned_extent() {
    local raster="$1"
    local zoom="$2"

    python3 - "${raster}" "${zoom}" <<'PY'
import json
import math
import subprocess
import sys

raster = sys.argv[1]
zoom = int(sys.argv[2])

info = json.loads(
    subprocess.check_output(["gdalinfo", "-json", raster], text=True)
)

transform = info["geoTransform"]
width, height = info["size"]

x0 = transform[0]
y0 = transform[3]
x1 = x0 + (transform[1] * width) + (transform[2] * height)
y1 = y0 + (transform[4] * width) + (transform[5] * height)

raster_min_x = min(x0, x1)
raster_max_x = max(x0, x1)
raster_min_y = min(y0, y1)
raster_max_y = max(y0, y1)

origin_shift = 20037508.342789244
world_width = origin_shift * 2.0
tile_count = 2 ** zoom
tile_width = world_width / tile_count

# Left/top boundaries are inclusive. Right/bottom boundaries are treated as
# exclusive so a raster ending exactly on a tile edge does not pull in an
# unnecessary neighbouring tile.
right_inside = math.nextafter(raster_max_x, -math.inf)
bottom_inside = math.nextafter(raster_min_y, math.inf)

min_tile_x = math.floor((raster_min_x + origin_shift) / tile_width)
max_tile_x = math.floor((right_inside + origin_shift) / tile_width)
min_tile_y = math.floor((origin_shift - raster_max_y) / tile_width)
max_tile_y = math.floor((origin_shift - bottom_inside) / tile_width)

min_tile_x = max(0, min(tile_count - 1, min_tile_x))
max_tile_x = max(0, min(tile_count - 1, max_tile_x))
min_tile_y = max(0, min(tile_count - 1, min_tile_y))
max_tile_y = max(0, min(tile_count - 1, max_tile_y))

min_x = -origin_shift + (min_tile_x * tile_width)
max_x = -origin_shift + ((max_tile_x + 1) * tile_width)
max_y = origin_shift - (min_tile_y * tile_width)
min_y = origin_shift - ((max_tile_y + 1) * tile_width)
resolution = tile_width / 256.0

print(min_x, min_y, max_x, max_y, resolution)
PY
}

# Build one zoom level for a regional overlay. The extent is expanded only to
# the XYZ tiles touching the high-resolution raster, while lower-resolution
# rasters are placed underneath it to fill the remainder of edge tiles.
build_regional_zoom() {
    local name="$1"
    local extent_raster="$2"
    local zoom="$3"
    shift 3

    local vrt="${BUILD_VRT}/${name}-z${zoom}.vrt"
    local min_x min_y max_x max_y resolution

    read -r min_x min_y max_x max_y resolution <<< "$(
        xyz_aligned_extent "${extent_raster}" "${zoom}"
    )"

    echo "${name} z${zoom}..."

    gdalbuildvrt \
        -overwrite \
        -resolution user \
        -tr "${resolution}" "${resolution}" \
        -te "${min_x}" "${min_y}" "${max_x}" "${max_y}" \
        "${vrt}" \
        "$@"

    gdal2tiles \
        --xyz \
        --zoom="${zoom}" \
        --resampling=cubic \
        --webviewer=none \
        --processes="${PROCESSES}" \
        "${vrt}" \
        "${COMBINED_TILES_DIR}"
}

echo "Cleaning generated output..."
rm -rf "${BUILD_DIR}" "${TILES_DIR}"

mkdir -p \
    "${BUILD_4326}" \
    "${BUILD_3857}" \
    "${BUILD_VRT}" \
    "${COMBINED_TILES_DIR}"

echo
echo "==> Building EPSG:4326 source rasters"

echo "Toril..."
gdal_translate \
    -a_srs EPSG:4326 \
    "${TORIL_SOURCE}" \
    "${BUILD_4326}/toril.tif"

echo "Faerûn..."
gdal_translate \
    -a_srs EPSG:4326 \
    "${FAERUN_SOURCE}" \
    "${BUILD_4326}/faerun.tif"

echo "Murann..."
gdal_translate \
    -a_srs EPSG:4326 \
    -a_ullr \
        "${MURANN_LEFT}" \
        "${MURANN_TOP}" \
        "${MURANN_RIGHT}" \
        "${MURANN_BOTTOM}" \
    "${MURANN_SOURCE}" \
    "${BUILD_4326}/murann.tif"

echo
echo "==> Clipping Toril to Web Mercator limits"

gdalwarp \
    -overwrite \
    -s_srs EPSG:4326 \
    -t_srs EPSG:4326 \
    -te_srs EPSG:4326 \
    -te \
        -180 \
        "-${MERCATOR_MAX_LAT}" \
        180 \
        "${MERCATOR_MAX_LAT}" \
    -r cubic \
    "${BUILD_4326}/toril.tif" \
    "${BUILD_4326}/toril-mercator-bounds.tif"

echo
echo "==> Building EPSG:3857 rasters"

echo "Toril..."
gdalwarp \
    -overwrite \
    -s_srs EPSG:4326 \
    -t_srs EPSG:3857 \
    -r cubic \
    -dstalpha \
    -multi \
    -wo NUM_THREADS=ALL_CPUS \
    -co TILED=YES \
    -co COMPRESS=DEFLATE \
    "${BUILD_4326}/toril-mercator-bounds.tif" \
    "${BUILD_3857}/toril.tif"

echo "Faerûn..."
gdalwarp \
    -overwrite \
    -s_srs EPSG:4326 \
    -t_srs EPSG:3857 \
    -r cubic \
    -dstalpha \
    -multi \
    -wo NUM_THREADS=ALL_CPUS \
    -co TILED=YES \
    -co COMPRESS=DEFLATE \
    "${BUILD_4326}/faerun.tif" \
    "${BUILD_3857}/faerun.tif"

echo "Murann..."
gdalwarp \
    -overwrite \
    -s_srs EPSG:4326 \
    -t_srs EPSG:3857 \
    -r cubic \
    -dstalpha \
    -multi \
    -wo NUM_THREADS=ALL_CPUS \
    -co TILED=YES \
    -co COMPRESS=DEFLATE \
    "${BUILD_4326}/murann.tif" \
    "${BUILD_3857}/murann.tif"

echo
echo "==> Building combined XYZ tile pyramid"

echo "Toril z0-7..."
gdal2tiles \
    --xyz \
    --zoom=0-7 \
    --resampling=cubic \
    --webviewer=none \
    --processes="${PROCESSES}" \
    "${BUILD_3857}/toril.tif" \
    "${COMBINED_TILES_DIR}"

echo
echo "Overlaying Faerûn z3-11..."
for zoom in $(seq 3 11); do
    build_regional_zoom \
        "faerun" \
        "${BUILD_3857}/faerun.tif" \
        "${zoom}" \
        "${BUILD_3857}/toril.tif" \
        "${BUILD_3857}/faerun.tif"
done

echo
echo "Overlaying Murann z12-20..."
for zoom in $(seq 12 20); do
    build_regional_zoom \
        "murann" \
        "${BUILD_3857}/murann.tif" \
        "${zoom}" \
        "${BUILD_3857}/toril.tif" \
        "${BUILD_3857}/faerun.tif" \
        "${BUILD_3857}/murann.tif"
done

echo
echo "==> Done"
echo
du -sh "${BUILD_DIR}" "${TILES_DIR}"
