# Forgotten Realms Rasters (Georeferenced)

This repository contains a collection of georeferenced raster maps for the Forgotten Realms. These assets provide the essential spatial baseline for the [Toril GIS](https://github.com/geospatial-grimoire/toril-gis) project and are shared to empower the fantasy cartography community in crafting lore-accurate, spatially consistent maps.

## Technical Specifications

All rasters in this repository are anchored using the [Toril Geographic Coordinate System (GCS)](https://www.geospatial-grimoire.com/blog/2024-11-09-crafting-coordinate-systems-for-faerun-and-beyond/). Where required, controlled distortions have been applied to rectify artistic source maps for a seamless fit within the global coordinate system.

### Georeferencing Standards
- **TIFF Files (.tif):** These are provided as **GeoTIFFs**. The spatial metadata and coordinate system information are embedded directly within the file header.
- **PNG & JPG Files:** These images are accompanied by **World Files (.pgw and .jgw)**. This is a standardized sidecar file format that contains the necessary transformation parameters (scale, rotation, and coordinates) to position the imagery correctly in geospatial software.

### Usage Instructions

#### Option A: Native Toril GCS (Recommended)
For the highest accuracy in **QGIS, ArcGIS, or other GIS software**, define the custom Toril GCS coordinate system using the WKT-CRS format found in [Toril GIS Resources](https://github.com/geospatial-grimoire/toril-gis/blob/main/resources/crs/toril_gcs.wkt).

#### Option B: WGS84 Workaround
If your software does not support custom coordinate systems, you could forcibly assign **WGS84 (EPSG:4326)** to these files. While the maps will load and be generally usable, please be aware that minor distortions or misalignments may occur compared to the native Toril GIS environment.

---

## Map Inventory

### 5. Community
- `AIF (2020) - Faerun_v2.jpg` (by Adam Whitehead - [Atlas of Ice & Fire](https://atlasoficeandfireblog.wordpress.com/))
- `AIF (2023) - Toril.png` (by Adam Whitehead - [Atlas of Ice & Fire](https://atlasoficeandfireblog.wordpress.com/))

---

## Wizards of the Coast Fan Content Policy
This project is unofficial Fan Content permitted under the Fan Content Policy. Not approved/endorsed by Wizards. Portions of the materials used are property of Wizards of the Coast. ©Wizards of the Coast LLC.

All materials are provided for non-commercial, educational, and hobbyist use.
