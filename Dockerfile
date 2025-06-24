# Stage 1: Builder
FROM node:22-bullseye-slim AS builder

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git curl python3 make g++ build-essential \
    libcairo2 libpango1.0-0 libjpeg-dev libgif-dev librsvg2-dev

# Install Node 22.14.0
RUN npm install -g n && n 22.14.0

# Set environment variables
ENV PATH="/usr/local/n/versions/node/22.14.0/bin:$PATH" \
    METEOR_ALLOW_SUPERUSER=true

# Install Yarn 4.7.0 via Corepack
RUN corepack enable && corepack prepare yarn@4.7.0 --activate

# Install Meteor
RUN curl https://install.meteor.com/ | sh

# Set working directory and clone Rocket.Chat source
WORKDIR /app
RUN git clone --branch 7.7.1 https://github.com/RocketChat/Rocket.Chat.git .

# Change to Meteor app directory
WORKDIR /app/app

# Install dependencies
RUN node --version
RUN yarn --version
RUN meteor --version
RUN yarn install

# Build Rocket.Chat bundle (output goes to /app/build)
RUN meteor build --directory ../build --architecture=os.linux.x86_64 --verbose

# Stage 2: Runtime
FROM node:22-bullseye-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y curl python3 make g++ build-essential && \
    npm install -g n && n 22.14.0

# Set environment variables
ENV PATH="/usr/local/n/versions/node/22.14.0/bin:$PATH" \
    ROOT_URL=http://localhost \
    MONGO_URL=mongodb://mongo:27017/rocketchat \
    PORT=3000

# Set working directory
WORKDIR /app

# Copy built Rocket.Chat bundle
COPY --from=builder /app/build/bundle /app

# Install production dependencies
RUN cd programs/server && yarn install

# Expose default port
EXPOSE 3000

# Run Rocket.Chat
CMD ["node", "main.js"]
