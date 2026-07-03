# Plugins are built in CI and assembled into merged-dist/ before this image is built.
# This image packages those static files into Caddy for serving.
FROM caddy:2-alpine

COPY Caddyfile /etc/caddy/Caddyfile
COPY merged-dist/ /srv/

EXPOSE 80
