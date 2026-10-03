FROM node:22-alpine
WORKDIR /app
COPY package.json ./
COPY src ./src
COPY public ./public
RUN mkdir /data && chown node:node /data
ENV NODE_ENV=production DATABASE_PATH=/data/proofboard.db TRUST_PROXY=1
VOLUME /data
EXPOSE 3000
USER node
CMD ["node", "--disable-warning=ExperimentalWarning", "src/server.js"]
