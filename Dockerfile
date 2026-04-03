# Runtime stage
FROM node:22-slim AS runner
WORKDIR /app

# Install bun for dependency management (used for migrations)
RUN npm install -g bun

# Copy only necessary files from builder
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/bun.lock ./bun.lock
COPY --from=builder /app/node_modules ./node_modules

# Copy migration files and scripts
COPY --from=builder /app/drizzle ./drizzle
COPY --from=builder /app/lib/db ./lib/db
COPY --from=builder /app/drizzle.config.ts ./drizzle.config.ts

# Proxy patch - route all fetch through HTTPS_PROXY
RUN echo "import { ProxyAgent, setGlobalDispatcher } from 'undici';\nif (process.env.HTTPS_PROXY) { setGlobalDispatcher(new ProxyAgent(process.env.HTTPS_PROXY)); }" > /app/proxy-patch.mjs

# Create entrypoint script for database migration
RUN echo '#!/bin/sh\n\
set -e\n\
echo "Running database migrations..."\n\
bun run migrate\n\
echo "Migrations completed. Starting server..."\n\
exec "$@"\n' > /app/docker-entrypoint.sh && chmod +x /app/docker-entrypoint.sh

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["node", "--import", "/app/proxy-patch.mjs", "/app/node_modules/.bin/next", "start", "-H", "0.0.0.0"]
