FROM alpine:latest

RUN apk add --no-cache \
    alpine-conf \
    squashfs-tools

COPY builder.sh /usr/bin/builder.sh
ENTRYPOINT ["/usr/bin/builder.sh"]