#!/usr/bin/env python3

import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

PLACE_MAPPING = {
    "City": "city",
    "Town": "town",
    "Village": "village",
}


# Existing OSM objects which should be updated rather than duplicated.
#
# IMPORTANT:
# The version must match the current version on the OSM server.
EXISTING_NODES = {
    "Murann": {
        "id": 178344,
        "version": 1,
    },
}


def add_tag(node, key, value):
    if value is None:
        return

    value = str(value).strip()

    if not value:
        return

    ET.SubElement(
        node,
        "tag",
        k=key,
        v=value,
    )


def get_point(geometry):
    geometry_type = geometry["type"]
    coordinates = geometry["coordinates"]

    if geometry_type == "Point":
        lon, lat, *_ = coordinates

        return lon, lat

    if geometry_type == "MultiPoint":
        if len(coordinates) != 1:
            raise ValueError(
                f"Expected single-point MultiPoint, got {len(coordinates)} points"
            )

        lon, lat, *_ = coordinates[0]

        return lon, lat

    raise ValueError(f"Expected Point or MultiPoint, got {geometry_type}")


def create_node(
    root,
    node_id,
    lon,
    lat,
    version=None,
):
    attributes = {
        "id": str(node_id),
        "visible": "true",
        "lon": str(lon),
        "lat": str(lat),
    }

    if version is not None:
        attributes["version"] = str(version)
        attributes["action"] = "modify"

    return ET.SubElement(
        root,
        "node",
        **attributes,
    )


def main():
    if len(sys.argv) != 3:
        print(
            f"Usage: {sys.argv[0]} input.geojson output.osm",
            file=sys.stderr,
        )

        sys.exit(1)

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])

    with input_path.open() as file:
        data = json.load(file)

    root = ET.Element(
        "osm",
        version="0.6",
        generator="toril-gis-to-osm",
        upload="true",
    )

    next_id = -1
    counts = {}
    updated = []

    for feature in data["features"]:
        geometry = feature.get("geometry")

        if not geometry:
            continue

        properties = feature.get("properties") or {}

        feature_class = properties.get("feature_class")

        if feature_class not in PLACE_MAPPING:
            raise ValueError(f"Unknown feature_class: {feature_class!r}")

        name = properties.get("name_en")

        lon, lat = get_point(geometry)

        existing = EXISTING_NODES.get(name)

        if existing:
            node = create_node(
                root,
                existing["id"],
                lon,
                lat,
                version=existing["version"],
            )

            updated.append(
                (
                    name,
                    existing["id"],
                    existing["version"],
                )
            )

        else:
            node = create_node(
                root,
                next_id,
                lon,
                lat,
            )

            next_id -= 1

        add_tag(
            node,
            "place",
            PLACE_MAPPING[feature_class],
        )

        add_tag(
            node,
            "name",
            name,
        )

        add_tag(
            node,
            "toril:feature_class",
            feature_class,
        )

        add_tag(
            node,
            "toril:feature_rank",
            properties.get("feature_rank"),
        )

        add_tag(
            node,
            "toril:source_uuid",
            properties.get("uuid"),
        )

        counts[feature_class] = counts.get(feature_class, 0) + 1

    ET.indent(
        root,
        space="  ",
    )

    ET.ElementTree(root).write(
        output_path,
        encoding="utf-8",
        xml_declaration=True,
    )

    print(f"Wrote {output_path}")
    print(f"Total: {sum(counts.values())}")
    print(f"Existing OSM nodes updated: {len(updated)}")

    for name, node_id, version in updated:
        print(f"  {name}: node {node_id}, version {version}")

    for feature_class, count in sorted(counts.items()):
        print(f"{feature_class}: {count}")


if __name__ == "__main__":
    main()
