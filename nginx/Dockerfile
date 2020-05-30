# https://github.com/dtan4/nginx-basic-auth-proxy
FROM nginx:1.17.10-alpine

# for htpasswd command
RUN apk add --no-cache --update \
      apache2-utils
RUN rm -f /etc/nginx/conf.d/*

ENV SERVER_NAME 127.0.0.1
ENV PORT 80
ENV CLIENT_MAX_BODY_SIZE 1m
ENV PROXY_READ_TIMEOUT 60s
ENV WORKER_PROCESSES auto

COPY spawn-polynote-notebooks-fargate/nginx/files/run.sh /
COPY spawn-polynote-notebooks-fargate/nginx/files/nginx.conf.tmpl /

RUN chmod +x run.sh

# use SIGQUIT for graceful shutdown
# c.f. http://nginx.org/en/docs/control.html
STOPSIGNAL SIGQUIT

ENTRYPOINT ["/run.sh"]
