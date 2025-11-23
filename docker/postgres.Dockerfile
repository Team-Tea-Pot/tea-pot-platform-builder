FROM postgres:16-alpine

ARG INIT_DIR=/docker-entrypoint-initdb.d

# Copy initialization scripts prepared by the platform builder
COPY docker/init-scripts/ $INIT_DIR/

# Ensure permissions
RUN chmod -R 755 $INIT_DIR || true

EXPOSE 5432

CMD ["postgres"]
