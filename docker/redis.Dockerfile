FROM redis:7-alpine

# Use official redis image as deployable image

EXPOSE 6379

CMD ["redis-server"]
