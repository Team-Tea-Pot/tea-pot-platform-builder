FROM alpine:3.18

# Minimal builder image with common tools; not strictly necessary for postgres,
# but kept for symmetry: this image can be extended to generate SQL/migrations
RUN apk add --no-cache bash curl git ca-certificates

WORKDIR /work

CMD ["/bin/sh"]
