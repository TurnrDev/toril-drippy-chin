FROM ghcr.io/osgeo/gdal:ubuntu-small-latest AS builder

WORKDIR /build

COPY source/ ./source/
COPY scripts/ ./scripts/

RUN chmod +x ./scripts/build-tiles.sh \
    && ./scripts/build-tiles.sh


FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY --from=builder /build/tiles/ /usr/share/nginx/html/

EXPOSE 80
