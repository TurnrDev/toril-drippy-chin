FROM debian:trixie-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    node-carto \
    renderd \
    libapache2-mod-tile \
    fonts-dejavu-core \
    fonts-noto-core \
    fonts-noto-cjk \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /openstreetmap-carto

CMD ["sleep", "infinity"]
