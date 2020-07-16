FROM alpine:3.11

RUN apk add --no-cache file curl jq

COPY entrypoint.sh /

RUN chmod +x /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
