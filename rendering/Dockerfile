FROM debian:trixie-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    carto \
    mapnik-utils \
    python3-mapnik \
    fonts-dejavu-core \
    fonts-noto-core \
    fonts-noto-cjk \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /openstreetmap-carto

CMD ["sleep", "infinity"]
