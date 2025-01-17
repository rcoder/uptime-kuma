# syntax = docker/dockerfile:1

ARG NODE_VERSION=20.10.0
ARG PORT=3000
FROM node:${NODE_VERSION}-slim as base

LABEL fly_launch_runtime="Node.js"

# Node.js app lives here
WORKDIR /app

# Set production environment
ENV NODE_ENV="production"

# Throw-away build stage to reduce size of final image
FROM base as build

# Install packages needed to build node modules
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential node-gyp pkg-config python-is-python3

# Install node modules
COPY --link .npmrc package-lock.json package.json ./
RUN npm ci --include=dev

# Copy application code
COPY --link . .

# Build application
RUN npm run build

# Remove development dependencies
RUN npm prune --omit=dev

# Final stage for app image
FROM base

RUN apt-get update && \
    apt-get install -y ca-certificates && \
    apt-get clean

# Copy built application
COPY --from=build /app /app
COPY --from=flyio/litefs:0.5 /usr/local/bin/litefs /usr/local/bin/litefs

COPY ./litefs.yml /app/litefs.yml

ENV UPTIME_KUMA_HOST="0.0.0.0"
ENV UPTIME_KUMA_PORT=${PORT}

EXPOSE ${PORT}

ENTRYPOINT litefs mount

