# Multi-stage build for production
FROM node:22-alpine AS builder

WORKDIR /frontend

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Build the application (adapter-node → ./build)
RUN npm run build

# Production stage
FROM node:22-alpine

WORKDIR /frontend

# Copy built application from builder stage
COPY --from=builder /frontend/build ./build
COPY --from=builder /frontend/package*.json ./

# Install only production dependencies
RUN npm ci --omit=dev

EXPOSE 80

# Node server config
ENV HOST=0.0.0.0
ENV PORT=80

# Start the application
CMD ["node", "build"]
