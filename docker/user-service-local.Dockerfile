# Simple deployment image that uses a pre-built binary
FROM alpine:latest

RUN apk --no-cache add ca-certificates tzdata

WORKDIR /root/

# Copy pre-built binary from local build
# Build the binary first: cd repos/teapot-user-service && make build
COPY repos/teapot-user-service/bin/server .

EXPOSE 8080

CMD ["./server"]
