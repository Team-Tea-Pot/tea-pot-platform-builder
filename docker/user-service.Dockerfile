# Runtime-only image using pre-built binary
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy pre-built binary from bin/ directory
COPY bin/server .

# Expose port
EXPOSE 8080

# Run
CMD ["./server"]
