ARG GLEAM_VERSION=v1.13.0
# Build stage - compile the application
FROM ghcr.io/gleam-lang/gleam:${GLEAM_VERSION}-erlang-alpine AS builder

# Add project code
COPY ./priv /quizterm/priv
COPY ./src /quizterm/src
COPY ./gleam.toml /quizterm/

RUN cd /quizterm && gleam deps download

# Compile the server code
RUN cd /quizterm \
  && gleam export erlang-shipment

# Runtime stage - slim image with only what's needed to run
FROM ghcr.io/gleam-lang/gleam:${GLEAM_VERSION}-erlang-alpine

# Copy the compiled server code from the builder stage
COPY --from=builder /quizterm/build/erlang-shipment /app

# Set up the entrypoint
WORKDIR /app
RUN echo -e '#!/bin/sh\nexec ./entrypoint.sh "$@"' > ./start.sh \
  && chmod +x ./start.sh

# Expose the port the server will run on
EXPOSE 1234

# Run the server
CMD ["./start.sh", "run"]
