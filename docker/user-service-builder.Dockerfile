FROM golang:1.24-alpine
RUN apk add --no-cache git build-base ca-certificates make
WORKDIR /src
CMD ["/bin/sh"]
