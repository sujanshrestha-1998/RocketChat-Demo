# Stage 1: Builder
FROM node:22-bullseye-slim AS builder

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git curl python3 make g++ build-essential \
    libcairo2 libpango1.0-0 libjpeg-dev libgif-dev librsvg2-dev

# Install Node.js 22.14.0
RUN npm install -g n && n 22.14.0

# Set environment variables
ENV PATH="/usr/local/n/versions/node/22.14.0/bin:$PATH" \
    METEOR_ALLOW_SUPERUSER=true

# Enable and install Yarn 4.7.0
RUN corepack enable && corepack prepare yarn@4.7.0 --activate

# Install Meteor
RUN curl https://install.meteor.com/ | sh

# Clone Rocket.Chat repo
WORKDIR /app
RUN git clone --branch 7.7.1 https://github.com/RocketChat/Rocket.Chat.git .

# Set working directory to actual Meteor project
WORKDIR /app/apps/meteor

# Verify tools
RUN node --version
RUN yarn --version
RUN meteor --version

# Install dependencies
RUN yarn install

# Build Rocket.Chat bundle
RUN meteor build --directory /app/build --architecture=os.linux.x86_64 --verbose

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

# Install server-side Node dependencies
RUN cd programs/server && yarn install

# Expose port
EXPOSE 3000

# Start Rocket.Chat
CMD ["node", "main.js"]
