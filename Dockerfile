FROM node:20-bookworm-slim

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
  && mv /tmp/deno /usr/local/bin/deno \
  && apt-mark auto '.*' > /dev/null \
  && find /usr/local -type f -executable -exec ldd '{}' ';' \
  | awk '/=>/ { print $(NF-1) }' \
  | sort -u \
  | xargs -r dpkg-query --search \
  | cut -d: -f1 \
  | sort -u \
  | xargs -r apt-mark manual \
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

# Create user first (without creating /app directory yet)
RUN groupadd -r rocketchat \
  && useradd -r -g rocketchat rocketchat

# Install build dependencies
RUN set -eux \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    fontconfig \
    g++ \
    make \
    python3 \
    ca-certificates \
    curl \
    gnupg \
    git \
  && rm -rf /var/lib/apt/lists/*

# Clone specific version from repository
RUN git clone --depth 1 --branch 7.1.6 https://github.com/RocketChat/Rocket.Chat.git /app

# Create uploads directory and set permissions
RUN mkdir -p /app/uploads \
  && chown -R rocketchat:rocketchat /app

VOLUME /app/uploads

# Now set the working directory
WORKDIR /app

# Set environment variables
ENV NODE_ENV=production
ENV DEPLOY_METHOD=docker-official
ENV MONGO_URL=mongodb://db:27017/meteor
ENV HOME=/tmp
ENV PORT=3000
ENV ROOT_URL=http://localhost:3000

# Install dependencies and build
RUN set -eux \
  && npm install --unsafe-perm=true \
  && npm run build \
  && cd apps/meteor/.meteor/local/build/programs/server \
  && npm install --unsafe-perm=true --production \
  && npm cache clear --force \
  && chown -R rocketchat:rocketchat /app

# Clean up build dependencies to reduce image size
RUN apt-get purge -y --auto-remove g++ make python3 git \
  && apt-get autoremove -y \
  && apt-get clean

USER rocketchat
WORKDIR /app/apps/meteor/.meteor/local/build
EXPOSE 3000
CMD ["node", "main.js"]
