# Stage 1: Build the site
FROM oven/bun:1 AS builder
WORKDIR /app
COPY package.json .
COPY bun.lockb .
RUN bun install
COPY . .
RUN bun run build

# Stage 2: Serve with Nginx
FROM nginx:alpine
# Remove default nginx index page
RUN rm -rf /usr/share/nginx/html/*
# Copy built assets from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html
# Default Nginx config usually works for static sites, but let's be explicit if needed.
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
