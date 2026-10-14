FROM caddy:2-alpine

COPY deploy/Caddyfile /etc/caddy/Caddyfile
COPY build/web/ /srv/

EXPOSE 8080
