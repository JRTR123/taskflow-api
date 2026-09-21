FROM node:20-alpine

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY src ./src

ARG FAIL_HEALTH=false
ENV FAIL_HEALTH=$FAIL_HEALTH
ENV PORT=8080
EXPOSE 8080

CMD ["node", "src/server.js"]
