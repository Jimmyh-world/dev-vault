FROM node:18-alpine

# Install required tools (curl for fetch-secrets.sh, jq for JSON parsing)
RUN apk add --no-cache curl jq

WORKDIR /app

COPY package.json package.json
RUN npm install

COPY server.js server.js

CMD ["node", "server.js"]
