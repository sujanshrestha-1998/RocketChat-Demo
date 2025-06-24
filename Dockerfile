# Stage 1: Builder
FROM node:22-bullseye-slim AS builder

# Install git, curl, python3, make, g++, build-essential and libs needed by Meteor and npm modules
RUN apt-get update && apt-get install -y \
    git curl python3 make g++ build-essential libcairo2 libpango1.0-0 libjpeg-dev libgif-dev librsvg2-dev

# Install n (Node version manager) and switch to exact Node 22.14.0
RUN npm install -g n && n 22.14.0

ENV PATH="/usr/local/n/versions/node/22.14.0/bin:$PATH"

# Enable corepack and prepare Yarn 4.7.0
RUN corepack enable && corepack prepare yarn@4.7.0 --activate

# Install Meteor
RUN curl https://install.meteor.com/ | sh

WORKDIR /app

# Clone Rocket.Chat source
RUN git clone --branch 7.7.1 https://github.com/RocketChat/Rocket.Chat.git .

# Verify versions (optional debug)
RUN node --version
RUN yarn --version
RUN meteor --version

# Install dependencies
RUN yarn install

# Build Rocket.Chat bundle (verbose output)
RUN meteor build --directory ./build --architecture=os.linux.x86_64 --verbose

# Stage 2: Runtime image
FROM node:22-bullseye-slim

# Install curl, python3, make, g++ and n, then install Node 22.14.0
RUN apt-get update && apt-get install -y curl python3 make g++ build-essential && \
    npm install -g n && n 22.14.0

ENV PATH="/usr/local/n/versions/node/22.14.0/bin:$PATH" \
    ROOT_URL=http://localhost \
    MONGO_URL=mongodb://mongo:27017/rocketchat \
    PORT=3000

WORKDIR /app

# Copy built bundle from builder
COPY --from=builder /app/build/bundle /app

# Install production dependencies in bundle
RUN cd programs/server && yarn install

EXPOSE 3000

CMD ["node", "main.js"]
