ARG GLEAM_VERSION=v1.15.0
# Build stage - compile the application
FROM ghcr.io/gleam-lang/gleam:${GLEAM_VERSION}-erlang-alpine AS builder

# Add project code
COPY ./server/priv /quizterm/server/priv
COPY ./server/src /quizterm/server/src
COPY ./server/gleam.toml /quizterm/server/
COPY ./client/src /quizterm/client/src
COPY ./client/gleam.toml /quizterm/client/
COPY ./shared/src /quizterm/shared/src
COPY ./shared/gleam.toml /quizterm/shared/gleam.toml

RUN cd /quizterm/server && gleam deps download

# Compile client code and move generated javascript to server project
RUN cd /quizterm/client \
  && gleam run -m lustre/dev build --minify --outdir=../server/priv/static


# Compile the server code
RUN cd /quizterm/server \
  && gleam export erlang-shipment

# Runtime stage - slim image with only what's needed to run
FROM ghcr.io/gleam-lang/gleam:${GLEAM_VERSION}-erlang-alpine

# Copy the compiled server code from the builder stage
COPY --from=builder /quizterm/server/build/erlang-shipment /app

# Set up the entrypoint
WORKDIR /app
RUN echo -e '#!/bin/sh\nexec ./entrypoint.sh "$@"' > ./start.sh \
  && chmod +x ./start.sh

# Expose the port the server will run on
EXPOSE 1234

# Run the server
CMD ["./start.sh", "run"]
