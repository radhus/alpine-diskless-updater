FROM alpine:latest

RUN apk add \
    alpine-conf \
    squashfs-tools

COPY builder.sh /usr/bin/builder.sh
ENTRYPOINT ["/usr/bin/builder.sh"]