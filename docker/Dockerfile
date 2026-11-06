FROM alpine:3.22

RUN apk add --no-cache git git-daemon \
    && addgroup -g 1000 git \
    && adduser -D -u 1000 -G git -h /home/git git \
    && mkdir -p /data \
    && chown git:git /data

USER 1000:1000
WORKDIR /data

EXPOSE 9418
