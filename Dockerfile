# Use the official Rocket.Chat build approach
FROM node:14.21.3-bullseye-slim

# Install system dependencies
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    fontconfig \
    g++ \
    git \
    gnupg \
    make \
    python3 \
    python3-dev \
    build-essential \
  && rm -rf /var/lib/apt/lists/*

# Install Deno
ENV DENO_VERSION=1.37.1
RUN ARCH= && dpkgArch="$(dpkg --print-architecture)" \
  && case "${dpkgArch##*-}" in \
  amd64) ARCH='x86_64';; \
  arm64) ARCH='aarch64';; \
  *) echo "unsupported Deno architecture"; exit 1 ;; \
  esac \
  && curl -fsSL https://dl.deno.land/release/v${DENO_VERSION}/deno-${ARCH}-unknown-linux-gnu.zip --output /tmp/deno-${ARCH}-unknown-linux-gnu.zip \
  && echo "3ebb3c234c4ea5d914eb394af340e08ae0787e95ca8ec2c58b869752760faa00 /tmp/deno-x86_64-unknown-linux-gnu.zip" | sha256sum -c - \
  && unzip /tmp/deno-${ARCH}-unknown-linux-gnu.zip -d /tmp \
  && rm /tmp/deno-${ARCH}-unknown-linux-gnu.zip \
  && chmod 755 /tmp/deno \
  && mv /tmp/deno /usr/local/bin/deno

# Create user
RUN groupadd -r rocketchat && useradd -r -g rocketchat rocketchat

# Clone repository
RUN git clone --depth 1 --branch 7.1.6 https://github.com/RocketChat/Rocket.Chat.git /app

WORKDIR /app

# Set environment variables
ENV NODE_ENV=production
ENV DEPLOY_METHOD=docker-official
ENV MONGO_URL=mongodb://db:27017/meteor
ENV HOME=/tmp
ENV PORT=3000
ENV ROOT_URL=http://localhost:3000
ENV METEOR_ALLOW_SUPERUSER=true

# Check if .nvmrc exists and what Node version is expected
RUN if [ -f .nvmrc ]; then echo "Required Node version: $(cat .nvmrc)"; fi
RUN echo "Current Node version: $(node --version)"
RUN echo "Current NPM version: $(npm --version)"

# Install Meteor (required for Rocket.Chat build)
RUN curl https://install.meteor.com/ | sh

# Build application using Meteor
RUN set -eux \
  && echo "Building with Meteor..." \
  && cd apps/meteor \
  && meteor npm install --unsafe-perm \
  && meteor build --directory /tmp/build-output --server-only

# Copy built application
RUN cp -R /tmp/build-output/bundle/* /app/

# Install production dependencies
RUN cd /app/programs/server && npm install --unsafe-perm --production

# Create uploads directory and set permissions
RUN mkdir -p /app/uploads \
  && chown -R rocketchat:rocketchat /app

VOLUME /app/uploads

# Clean up
RUN apt-get purge -y --auto-remove g++ make python3-dev build-essential git curl \
  && apt-get autoremove -y \
  && apt-get clean \
  && rm -rf /tmp/* /var/tmp/*

USER rocketchat
WORKDIR /app
EXPOSE 3000
CMD ["node", "main.js"]
