# Stage 1: Build the site
FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json .
RUN npm install
COPY . .
RUN npm run build

# Stage 2: Serve with Nginx
FROM nginx:alpine
# Copy built assets from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html
# Default Nginx config usually works for static sites, but let's be explicit if needed.
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
