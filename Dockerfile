# Stage 1: Builder
FROM node:22-bullseye-slim AS builder

RUN apt-get update && apt-get install -y \
    git curl python3 make g++ build-essential libcairo2 libpango1.0-0 libjpeg-dev libgif-dev librsvg2-dev

RUN npm install -g n && n 22.14.0

ENV PATH="/usr/local/n/versions/node/22.14.0/bin:$PATH" \
    METEOR_ALLOW_SUPERUSER=true

RUN corepack enable && corepack prepare yarn@4.7.0 --activate

RUN curl https://install.meteor.com/ | sh

WORKDIR /app

RUN git clone --branch 7.7.1 https://github.com/RocketChat/Rocket.Chat.git .

RUN node --version
RUN yarn --version
RUN meteor --version

RUN yarn install

RUN meteor build --directory ./build --architecture=os.linux.x86_64 --verbose

# Stage 2: Runtime
FROM node:22-bullseye-slim

RUN apt-get update && apt-get install -y curl python3 make g++ build-essential && \
    npm install -g n && n 22.14.0

ENV PATH="/usr/local/n/versions/node/22.14.0/bin:$PATH" \
    ROOT_URL=http://localhost \
    MONGO_URL=mongodb://mongo:27017/rocketchat \
    PORT=3000

WORKDIR /app

COPY --from=builder /app/build/bundle /app

RUN cd programs/server && yarn install

EXPOSE 3000

CMD ["node", "main.js"]
