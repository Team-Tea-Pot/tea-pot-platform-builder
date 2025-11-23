# Build stage
FROM golang:1.24-alpine AS builder

RUN apk add --no-cache git make

WORKDIR /app

# Copy all source code
COPY . .

# Try to generate code, but continue even if it fails
RUN make generate || echo "Code generation skipped"

# Download dependencies (ignore errors for now if generated code is missing)
RUN go mod download || true

# Build binary (if dependencies are missing, this will fail properly)
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o server cmd/server/main.go

# Runtime stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy binary from builder
COPY --from=builder /app/server .

# Expose port
EXPOSE 8080

# Run
CMD ["./server"]
