FROM debian:trixie-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    apache2 \
    node-carto \
    renderd \
    libapache2-mod-tile \
    osm2pgsql \
    gdal-bin \
    python3 \
    python3-yaml \
    python3-requests \
    python3-psycopg2 \
    fonts-dejavu-core \
    fonts-noto-core \
    fonts-noto-cjk \
    ca-certificates \
    curl \
    && a2enmod headers tile \
    && rm -rf /var/lib/apt/lists/*

COPY apache.conf /etc/apache2/conf-available/dnd-tiles.conf
RUN a2enconf dnd-tiles

WORKDIR /openstreetmap-carto

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

CMD ["/usr/local/bin/entrypoint.sh"]
