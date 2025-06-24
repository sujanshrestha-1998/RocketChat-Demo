# ----------------------------
# Stage 1: Build Rocket.Chat
# ----------------------------
FROM node:22-bullseye-slim AS builder

# Install curl, git, corepack (for yarn 4)
RUN apt-get update && apt-get install -y git curl && corepack enable

# Set yarn version to 4.7.0
RUN corepack prepare yarn@4.7.0 --activate

# Install Meteor
RUN curl https://install.meteor.com/ | sh

WORKDIR /app

# Clone Rocket.Chat source
RUN git clone --branch 7.7.1 https://github.com/RocketChat/Rocket.Chat.git .

# Install dependencies using yarn
RUN yarn install

# Build Rocket.Chat bundle
RUN meteor build --directory ./build --architecture=os.linux.x86_64

# ----------------------------
# Stage 2: Runtime image
# ----------------------------
FROM node:22-bullseye-slim

ENV ROOT_URL=http://localhost \
    MONGO_URL=mongodb://mongo:27017/rocketchat \
    PORT=3000

WORKDIR /app

# Copy built bundle from builder
COPY --from=builder /app/build/bundle /app

# Install server dependencies
RUN cd programs/server && yarn install

EXPOSE 3000

CMD ["node", "main.js"]
