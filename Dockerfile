# 1. BUILD FRONTEND source with webpack
FROM yuvytung/node AS builder-frontend
ARG env=production
ENV npm_config_cache=/tmp/.npm
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm install
COPY webpack.config.js babel.config.js tsconfig.json .eslintrc .editorconfig ./
COPY client ./client
RUN npm run build-frontend

# 2. BUILD BACKEND source from .ts, uses dev-dependencies
FROM yuvytung/node AS builder-backend
ARG env=production
ENV npm_config_cache=/tmp/.npm
WORKDIR /app
COPY package.json package-lock.json tsconfig.json ./
RUN npm install
COPY src ./src
RUN npm run build-backend

# 3. BUILD FINAL IMAGE
FROM yuvytung/node
ARG env=production
ENV NODE_ENV=${env}
RUN mkdir -p /app && \
chown 1001:1001 /app
WORKDIR /app
RUN install_packages wget
COPY --chown=1001:1001  --from=builder-frontend /app/dist /app/dist
COPY --chown=1001:1001  --from=builder-backend /app/app /app/app

# 3.1 copy only required files
COPY --chown=1001:1001 ./migrations /app/migrations
COPY --chown=1001:1001 ./container-health.js /app/container-health.js
COPY --chown=1001:1001 ./knexfile.js /app/knexfile.js
COPY --chown=1001:1001  ./package.json /app/package.json
COPY --chown=1001:1001 ./package-lock.json /app/package-lock.json

# 3.2 install production dependencies only. Cleanup cache after that
RUN mkdir -p /.npm \
&& npm ci \
&& rm -rf /.npm

USER 1001
HEALTHCHECK --interval=10s --timeout=5s --start-period=10s --retries=3 CMD [ "node", "container-health.js" ]
EXPOSE 3000

CMD ["node", "app/schema-registry.js"]
