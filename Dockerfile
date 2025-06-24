# --------------------
# Stage 1: Builder
# --------------------
FROM node:22-bullseye-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl python3 make g++ build-essential \
    libcairo2 libpango1.0-0 libjpeg-dev libgif-dev librsvg2-dev \
    && rm -rf /var/lib/apt/lists/*

# Enable Yarn 4.7.0
RUN corepack enable && corepack prepare yarn@4.7.0 --activate

# Install Meteor
ENV METEOR_ALLOW_SUPERUSER=true
RUN curl https://install.meteor.com/ | sh

# Install Deno (required for Rocket.Chat apps-engine build)
RUN curl -fsSL https://deno.land/install.sh | sh
ENV DENO_INSTALL="/root/.deno"
ENV PATH="$DENO_INSTALL/bin:$PATH"

# Set workdir and clone Rocket.Chat source
WORKDIR /app
RUN git clone --depth 1 --branch 7.7.1 https://github.com/RocketChat/Rocket.Chat.git .
RUN ls -la

# Install dependencies and build packages
RUN yarn install
RUN yarn build

# Build Meteor bundle
WORKDIR /app/apps/meteor
RUN meteor build --directory /app/build --architecture=os.linux.x86_64 --verbose

# --------------------
# Stage 2: Runtime
# --------------------
FROM node:22-bullseye-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcairo2 libpango1.0-0 libjpeg62-turbo libgif7 librsvg2-2 \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV ROOT_URL=http://localhost \
    MONGO_URL=mongodb://mongo:27017/rocketchat \
    PORT=3000 \
    NODE_ENV=production

WORKDIR /app

# Copy built bundle from builder stage
COPY --from=builder /app/build/bundle /app

# Install server dependencies in bundle
RUN cd programs/server && \
    yarn install --production --ignore-scripts && \
    yarn cache clean

# Create a non-root user and switch to it
RUN useradd -m myuser && chown -R myuser:myuser /app
USER myuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/api/v1/info || exit 1

CMD ["node", "main.js"]
