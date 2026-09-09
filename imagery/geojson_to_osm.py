#!/usr/bin/env python3

import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

MAX_WAY_NODES = 1000


class IdGenerator:
    def __init__(self):
        self._next_id = -1

    def next(self):
        value = self._next_id
        self._next_id -= 1
        return value


node_ids = IdGenerator()
way_ids = IdGenerator()
relation_ids = IdGenerator()


def add_tags(parent, properties):
    ET.SubElement(parent, "tag", k="natural", v="land")

    name = properties.get("name_en")
    if name:
        name = str(name).strip()

        if name and name.lower() != "unnamed":
            ET.SubElement(parent, "tag", k="name", v=name)

    feature_class = properties.get("feature_class")
    if feature_class:
        ET.SubElement(
            parent,
            "tag",
            k="toril:feature_class",
            v=str(feature_class),
        )

    feature_rank = properties.get("feature_rank")
    if feature_rank is not None:
        ET.SubElement(
            parent,
            "tag",
            k="toril:feature_rank",
            v=str(feature_rank),
        )

    source_uuid = properties.get("uuid")
    if source_uuid:
        ET.SubElement(
            parent,
            "tag",
            k="toril:source_uuid",
            v=str(source_uuid),
        )


def create_node(root, lon, lat):
    node_id = node_ids.next()

    ET.SubElement(
        root,
        "node",
        id=str(node_id),
        visible="true",
        lon=str(lon),
        lat=str(lat),
    )

    return node_id


def normalize_ring(ring):
    """
    Remove the duplicate closing coordinate.

    GeoJSON polygon rings normally contain:
        A -> B -> C -> A

    OSM closed ways instead reference the same node at
    the beginning and end:
        nodeA -> nodeB -> nodeC -> nodeA
    """
    if len(ring) > 1 and ring[0] == ring[-1]:
        return ring[:-1]

    return ring


def create_ring_nodes(root, ring):
    ring = normalize_ring(ring)

    return [
        create_node(root, lon, lat)
        for lon, lat, *rest in ring
    ]


def create_closed_way(root, node_refs, properties=None):
    way_id = way_ids.next()

    way = ET.SubElement(
        root,
        "way",
        id=str(way_id),
        visible="true",
    )

    for node_ref in node_refs:
        ET.SubElement(
            way,
            "nd",
            ref=str(node_ref),
        )

    ET.SubElement(
        way,
        "nd",
        ref=str(node_refs[0]),
    )

    if properties is not None:
        add_tags(way, properties)

    return way_id


def split_ring_into_ways(root, node_refs):
    """
    Split one closed polygon ring into connected open OSM ways.

    Adjacent segments share their endpoint.

    For example:
        way 1: A B C D
        way 2: D E F G
        way 3: G H A

    Together they form one closed ring in a multipolygon relation.
    """
    if len(node_refs) + 1 <= MAX_WAY_NODES:
        return [
            create_closed_way(root, node_refs)
        ]

    way_refs = []

    # Each open segment may contain MAX_WAY_NODES nodes.
    # We advance by one fewer node so adjacent segments
    # share their endpoint.
    segment_capacity = MAX_WAY_NODES
    step = segment_capacity - 1

    start = 0

    while start < len(node_refs):
        end = min(start + segment_capacity, len(node_refs))

        segment = node_refs[start:end]

        # Last segment must connect back to the first node.
        if end == len(node_refs):
            if segment[-1] != node_refs[0]:
                segment = segment + [node_refs[0]]

        way_id = way_ids.next()

        way = ET.SubElement(
            root,
            "way",
            id=str(way_id),
            visible="true",
        )

        for node_ref in segment:
            ET.SubElement(
                way,
                "nd",
                ref=str(node_ref),
            )

        way_refs.append(way_id)

        if end == len(node_refs):
            break

        # The next segment starts on this segment's last node.
        start = end - 1

    return way_refs


def create_relation(root, outer_ways, inner_ways, properties):
    relation_id = relation_ids.next()

    relation = ET.SubElement(
        root,
        "relation",
        id=str(relation_id),
        visible="true",
    )

    for way_id in outer_ways:
        ET.SubElement(
            relation,
            "member",
            type="way",
            ref=str(way_id),
            role="outer",
        )

    for way_id in inner_ways:
        ET.SubElement(
            relation,
            "member",
            type="way",
            ref=str(way_id),
            role="inner",
        )

    ET.SubElement(
        relation,
        "tag",
        k="type",
        v="multipolygon",
    )

    add_tags(relation, properties)

    return relation_id


def polygons_from_geometry(geometry):
    geometry_type = geometry["type"]
    coordinates = geometry["coordinates"]

    if geometry_type == "Polygon":
        return [coordinates]

    if geometry_type == "MultiPolygon":
        return coordinates

    raise ValueError(
        f"Unsupported geometry type: {geometry_type}"
    )


def feature_requires_relation(polygons):
    if len(polygons) > 1:
        return True

    for polygon in polygons:
        if len(polygon) > 1:
            return True

        outer_ring = normalize_ring(polygon[0])

        # +1 because a closed OSM way repeats its first node.
        if len(outer_ring) + 1 > MAX_WAY_NODES:
            return True

    return False


def convert_feature(root, feature):
    geometry = feature.get("geometry")

    if geometry is None:
        return

    properties = feature.get("properties") or {}
    polygons = polygons_from_geometry(geometry)

    if not feature_requires_relation(polygons):
        outer_ring = polygons[0][0]
        node_refs = create_ring_nodes(root, outer_ring)

        create_closed_way(
            root,
            node_refs,
            properties=properties,
        )

        return

    outer_ways = []
    inner_ways = []

    for polygon in polygons:
        outer_ring = polygon[0]

        outer_nodes = create_ring_nodes(
            root,
            outer_ring,
        )

        outer_ways.extend(
            split_ring_into_ways(
                root,
                outer_nodes,
            )
        )

        for inner_ring in polygon[1:]:
            inner_nodes = create_ring_nodes(
                root,
                inner_ring,
            )

            inner_ways.extend(
                split_ring_into_ways(
                    root,
                    inner_nodes,
                )
            )

    create_relation(
        root,
        outer_ways,
        inner_ways,
        properties,
    )


def indent(element, level=0):
    prefix = "\n" + "  " * level

    if len(element):
        if not element.text or not element.text.strip():
            element.text = prefix + "  "

        for child in element:
            indent(child, level + 1)

        if not child.tail or not child.tail.strip():
            child.tail = prefix

    if level and (not element.tail or not element.tail.strip()):
        element.tail = prefix


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
    )

    features = data.get("features", [])

    for index, feature in enumerate(features, start=1):
        convert_feature(root, feature)

        if index % 100 == 0:
            print(
                f"Converted {index}/{len(features)} features",
                file=sys.stderr,
            )

    indent(root)

    tree = ET.ElementTree(root)

    tree.write(
        output_path,
        encoding="utf-8",
        xml_declaration=True,
    )

    print(
        f"Wrote {output_path}",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
