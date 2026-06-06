# Build from the repository root:
#   docker build -f apps/backend/Dockerfile -t task-forge-backend .

FROM node:22-alpine AS base

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

RUN corepack enable && corepack prepare pnpm@9.15.9 --activate

WORKDIR /app

FROM base AS builder

ENV NODE_ENV=development

# bcrypt and other native modules need build tooling on Alpine
RUN apk add --no-cache python3 make g++

COPY pnpm-lock.yaml pnpm-workspace.yaml package.json ./

COPY packages/shared/package.json packages/shared/tsconfig.json ./packages/shared/
COPY packages/shared/src ./packages/shared/src

COPY apps/backend/package.json apps/backend/tsconfig.json ./apps/backend/
COPY apps/backend/src ./apps/backend/src

RUN pnpm install --frozen-lockfile --prod=false

RUN pnpm --filter @task-forge/shared build
RUN pnpm --filter @task-forge/backend build

RUN pnpm --filter @task-forge/backend --prod deploy /prod

FROM base AS runner

RUN apk add --no-cache libc6-compat

ENV NODE_ENV=production

WORKDIR /app

COPY --from=builder /prod ./

USER node

EXPOSE 3000

CMD ["sh", "-c", "node node_modules/typeorm/cli.js migration:run -d dist/database/data-source.js && node dist/app.js"]
