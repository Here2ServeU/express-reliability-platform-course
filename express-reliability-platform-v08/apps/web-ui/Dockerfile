FROM nginx:alpine
# API_UPSTREAM defaults to the in-cluster Helm service name (node-api's
# Service is "<release>-<chart>" = node-api-node-api); docker-compose.yml
# overrides this to flask-api:5000 for the local stack, which has no
# node-api container. The nginx image's docker-entrypoint runs envsubst on
# every file under /etc/nginx/templates/*.template at startup, substituting
# only variables that are actually set in the environment — nginx's own
# built-in $uri/$host/$remote_addr are untouched because they aren't env vars.
ENV API_UPSTREAM=node-api-node-api:3000
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
