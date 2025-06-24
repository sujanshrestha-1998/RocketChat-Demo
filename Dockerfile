# ----------------------------
# Stage 1: Build Rocket.Chat
# ----------------------------
FROM node:14-bullseye-slim AS builder

# Install git and curl (required for clone + Meteor)
RUN apt-get update && apt-get install -y git curl

# Install Meteor
RUN curl https://install.meteor.com/ | sh

WORKDIR /app

# Clone your custom Rocket.Chat repo (replace with your fork if needed)
RUN git clone --branch 7.7.1 https://github.com/RocketChat/Rocket.Chat.git .

# Install dependencies
RUN npm install
RUN meteor npm install

# Build Rocket.Chat bundle for Linux
RUN meteor build --directory ./build --architecture=os.linux.x86_64

# ----------------------------
# Stage 2: Runtime Image
# ----------------------------
FROM node:14-bullseye-slim

ENV ROOT_URL=http://localhost \
    MONGO_URL=mongodb://mongo:27017/rocketchat \
    PORT=3000

WORKDIR /app

# Copy built bundle from builder stage
COPY --from=builder /app/build/bundle /app

# Install production dependencies
RUN cd programs/server && npm install

EXPOSE 3000

CMD ["node", "main.js"]
