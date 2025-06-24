# Stage 1: Builder
FROM node:14-bullseye-slim AS builder

# Install Meteor
RUN curl https://install.meteor.com/ | sh

WORKDIR /app

# Clone your custom Rocket.Chat repo and checkout 7.7.1
RUN git clone --branch 7.7.1 https://github.com/RocketChat/Rocket.Chat.git .

# Install dependencies
RUN npm install
RUN meteor npm install

# Build Meteor app bundle
RUN meteor build --directory ./build --architecture=os.linux.x86_64

# Stage 2: Runtime image
FROM node:14-bullseye-slim

ENV ROOT_URL=http://localhost \
    MONGO_URL=mongodb://mongo:27017/rocketchat \
    PORT=3000

WORKDIR /app

# Copy bundle from builder
COPY --from=builder /app/build/bundle /app

# Install server dependencies inside bundle
RUN cd programs/server && npm install

EXPOSE 3000

CMD ["node", "main.js"]
