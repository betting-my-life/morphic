# Build stage
FROM node:22-slim AS builder

WORKDIR /app

RUN npm install -g bun

COPY package.json bun.lock ./
RUN bun install

COPY . .
RUN npx next telemetry disable
ENV DATABASE_URL=postgresql://user:pass@localhost:5432/db
RUN npm run build

# Runtime stage
FROM node:22-slim AS runner
WORKDIR /app

COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/bun.lock ./bun.lock
COPY --from=builder /app/node_modules ./node_modules

RUN npm install undici --legacy-peer-deps

COPY --from=builder /app/drizzle ./drizzle
COPY --from=builder /app/lib/db ./lib/db
COPY --from=builder /app/drizzle.config.ts ./drizzle.config.ts

# Proxy patch
RUN printf "import { ProxyAgent, setGlobalDispatcher } from 'node:undici';\nif (process.env.HTTPS_PROXY) { setGlobalDispatcher(new ProxyAgent(process.env.HTTPS_PROXY)); }\n" > /app/proxy-patch.mjs

RUN printf '#!/bin/sh\nset -e\necho "Running database migrations..."\nbun run migrate\necho "Migrations completed. Starting server..."\nexec "$@"\n' > /app/docker-entrypoint.sh && chmod +x /app/docker-entrypoint.sh

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["node", "--import", "/app/proxy-patch.mjs", "/app/node_modules/.bin/next", "start", "-H", "0.0.0.0"]
