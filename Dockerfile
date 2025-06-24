# Use official Node.js base image (adjust version if needed)
FROM node:14-bullseye-slim

ENV ROOT_URL=http://localhost \
    MONGO_URL=mongodb://mongo:27017/rocketchat \
    PORT=3000

WORKDIR /app

# Copy the built Meteor bundle (assume you build locally or CI before Docker build)
COPY ./bundle /app

# Install server dependencies
RUN cd programs/server && npm install

EXPOSE 3000

CMD ["node", "main.js"]
