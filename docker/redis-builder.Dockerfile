FROM alpine:3.18
RUN apk add --no-cache bash curl git
WORKDIR /work
CMD ["/bin/sh"]
