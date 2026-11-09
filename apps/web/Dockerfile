# Build the Next.js app with the same Node.js 24 line used by local development.
FROM node:26.13.0-bookworm-slim AS build
WORKDIR /workspace

# Install all workspace dependencies from the repository lockfile.
COPY package.json package-lock.json ./
COPY apps/web/package.json apps/web/package.json
RUN npm ci

# Copy the web app source and create its production build.
COPY apps/web/ apps/web/
WORKDIR /workspace/apps/web
RUN npm run build

# Run the production server in a separate, non-root runtime image.
FROM node:26.13.0-bookworm-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN groupadd --system --gid 10001 appuser \
    && useradd --system --uid 10001 --gid appuser --create-home appuser

# Install only production dependencies in the runtime image.
COPY package.json package-lock.json ./
COPY apps/web/package.json apps/web/package.json
RUN npm ci --omit=dev

# Copy the production build and the Next.js config used to serve it.
COPY --from=build --chown=appuser:appuser /workspace/apps/web/.next ./apps/web/.next
COPY --from=build --chown=appuser:appuser /workspace/apps/web/next.config.ts ./apps/web/next.config.ts
COPY --from=build --chown=appuser:appuser /workspace/apps/web/package.json ./apps/web/package.json

USER 10001
EXPOSE 3000
CMD ["npm", "run", "start", "-w", "@my-atlas/web"]
