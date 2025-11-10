ARG GLEAM_VERSION=v1.13.0

# Build stage - compile the application
FROM ghcr.io/gleam-lang/gleam:${GLEAM_VERSION}-erlang-alpine AS builder

# Add project code
COPY ./src /src
COPY ./gleam.toml /

EXPOSE 1234
# Run the server
CMD ["gleam", "run"]
