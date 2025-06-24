FROM node:14-bookworm-slim

# Install Deno
ENV DENO_VERSION=1.37.1
RUN ARCH= && dpkgArch="$(dpkg --print-architecture)" \
  && case "${dpkgArch##*-}" in \
  amd64) ARCH='x86_64';; \
  arm64) ARCH='aarch64';; \
  *) echo "unsupported Deno architecture"; exit 1 ;; \
  esac \
  && set -ex \
  && apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip && rm -rf /var/lib/apt/lists/* \
  && curl -fsSL https://dl.deno.land/release/v${DENO_VERSION}/deno-${ARCH}-unknown-linux-gnu.zip --output /tmp/deno-${ARCH}-unknown-linux-gnu.zip \
  && echo "3ebb3c234c4ea5d914eb394af340e08ae0787e95ca8ec2c58b869752760faa00 /tmp/deno-x86_64-unknown-linux-gnu.zip" | sha256sum -c - \
  && unzip /tmp/deno-${ARCH}-unknown-linux-gnu.zip -d /tmp \
  && rm /tmp/deno-${ARCH}-unknown-linux-gnu.zip \
  && chmod 755 /tmp/deno \
  && mv /tmp/deno /usr/local/bin/deno

# Create app user
RUN groupadd -r rocketchat && useradd -r -g rocketchat rocketchat

# Install build deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    fontconfig \
    g++ \
    make \
    python3 \
    ca-certificates \
    curl \
    gnupg \
    git \
    python3-dev \
    build-essential \
  && rm -rf /var/lib/apt/lists/*

# Clone Rocket.Chat
RUN git clone --depth 1 --branch 7.1.6 https://github.com/RocketChat/Rocket.Chat.git /app

# Set correct ownership and create uploads
RUN mkdir -p /app/uploads && chown -R rocketchat:rocketchat /app

VOLUME /app/uploads
WORKDIR /app

# Environment variables
ENV NODE_ENV=production \
    DEPLOY_METHOD=docker-official \
    MONGO_URL=mongodb://db:27017/meteor \
    HOME=/tmp \
    PORT=3000 \
    ROOT_URL=http://localhost:3000 \
    NODE_OPTIONS="--max-old-space-size=4096" \
    METEOR_ALLOW_SUPERUSER=true

# Install dependencies
RUN yarn install --network-timeout 300000

# Build app
RUN yarn build

# Install prod deps in built server
RUN cd apps/meteor/.meteor/local/build/programs/server \
  && npm install --unsafe-perm=true --production --timeout=300000

# Clean up
RUN yarn cache clean \
  && npm cache clean --force \
  && chown -R rocketchat:rocketchat /app \
  && apt-get purge -y --auto-remove g++ make python3-dev build-essential git \
  && apt-get autoremove -y && apt-get clean

USER rocketchat
WORKDIR /app/apps/meteor/.meteor/local/build
EXPOSE 3000
CMD ["node", "main.js"]
