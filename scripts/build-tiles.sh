#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SOURCE_DIR="${ROOT_DIR}/source"
BUILD_DIR="${ROOT_DIR}/build"
BUILD_4326="${BUILD_DIR}/4326"
BUILD_3857="${BUILD_DIR}/3857"
TILES_DIR="${ROOT_DIR}/tiles"

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

echo "Cleaning generated output..."
rm -rf "${BUILD_DIR}" "${TILES_DIR}"

mkdir -p \
    "${BUILD_4326}" \
    "${BUILD_3857}" \
    "${TILES_DIR}"

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
echo "==> Building XYZ tile pyramids"

echo "Toril..."
gdal2tiles \
    --xyz \
    --zoom=0-7 \
    --resampling=cubic \
    --webviewer=none \
    --processes="${PROCESSES}" \
    "${BUILD_3857}/toril.tif" \
    "${TILES_DIR}/toril"

echo "Faerûn..."
gdal2tiles \
    --xyz \
    --zoom=3-11 \
    --resampling=cubic \
    --webviewer=none \
    --processes="${PROCESSES}" \
    "${BUILD_3857}/faerun.tif" \
    "${TILES_DIR}/faerun"

echo "Murann..."
gdal2tiles \
    --xyz \
    --zoom=12-20 \
    --resampling=cubic \
    --webviewer=none \
    --processes="${PROCESSES}" \
    "${BUILD_3857}/murann.tif" \
    "${TILES_DIR}/murann"

echo
echo "==> Done"
echo
du -sh "${BUILD_DIR}" "${TILES_DIR}"

