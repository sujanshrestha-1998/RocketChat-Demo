# Stage 1: Builder
FROM node:22-bullseye-slim AS builder

# Install git, curl, python3, make, g++ (for native builds) and n (Node version manager)
RUN apt-get update && apt-get install -y git curl python3 make g++ && \
    npm install -g n

# Install exact Node 22.14.0 with n
RUN n 22.14.0

# Make sure PATH uses Node 22.14.0
ENV PATH="/usr/local/n/versions/node/22.14.0/bin:$PATH"

# Enable Corepack and prepare Yarn 4.7.0
RUN corepack enable && corepack prepare yarn@4.7.0 --activate

# Install Meteor
RUN curl https://install.meteor.com/ | sh

WORKDIR /app

# Clone Rocket.Chat v7.7.1 source
RUN git clone --branch 7.7.1 https://github.com/RocketChat/Rocket.Chat.git .

# Install dependencies with Yarn
RUN yarn install

# Build Rocket.Chat bundle for Linux
RUN meteor build --directory ./build --architecture=os.linux.x86_64

# Stage 2: Runtime
FROM node:22-bullseye-slim

# Install n and set exact Node 22.14.0 in runtime image
RUN apt-get update && apt-get install -y curl python3 make g++ && \
    npm install -g n && \
    n 22.14.0

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
