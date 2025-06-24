# --------------------
# Stage 1: Builder
# --------------------
FROM node:22-bullseye-slim AS builder

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git curl unzip python3 make g++ build-essential \
    libcairo2 libpango1.0-0 libjpeg-dev libgif-dev librsvg2-dev \
    && apt-get clean

# Install Node 22.14.0 using n
RUN npm install -g n && n 22.14.0
ENV PATH="/usr/local/n/versions/node/22.14.0/bin:$PATH"

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
RUN git clone --branch 7.7.1 https://github.com/RocketChat/Rocket.Chat.git .
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
RUN apt-get update && apt-get install -y curl python3 make g++ build-essential

# Install Node 22.14.0 for runtime
RUN npm install -g n && n 22.14.0
ENV PATH="/usr/local/n/versions/node/22.14.0/bin:$PATH"

# Set environment variables (update as needed)
ENV ROOT_URL=http://localhost \
    MONGO_URL=mongodb://mongo:27017/rocketchat \
    PORT=3000

WORKDIR /app

# Copy built bundle from builder stage
COPY --from=builder /app/build/bundle /app

# Install server dependencies in bundle
RUN cd programs/server && yarn install --production

EXPOSE 3000

CMD ["node", "main.js"]
