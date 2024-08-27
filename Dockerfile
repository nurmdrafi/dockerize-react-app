# Stage 1: Install dependencies
FROM ubuntu:24.10 AS deps

# Set working directory
WORKDIR /app

# Install Node.js
RUN apt update \
    && apt-get install -y curl \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

# Copy package json
COPY package.json package-lock.json ./

# Install packages
RUN npm install --force

# Stage 2: Build the project
FROM ubuntu:24.10 AS builder

# Set working directory
WORKDIR /app

# Install Node.js
RUN apt update \
    && apt-get install -y curl \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

# Copies everything over to Docker filesystem
COPY . .
COPY --from=deps /app/node_modules ./node_modules

# Build for production
RUN npm run build

# Stage 3: Serve the project
FROM nginx:alpine AS runner

# Nginx config
RUN rm -rf /etc/nginx/conf.d
COPY conf /etc/nginx

# Static build folde
COPY --from=builder /app/build /usr/share/nginx/html/

# Default port exposure
EXPOSE 80

# Copy .env file and shell script to Docker filesystem
WORKDIR /usr/share/nginx/html
COPY ./env.production.sh .
COPY .env.production .

# Make shell script executable
RUN chmod +x env.production.sh

# Start Nginx server
CMD ["/bin/sh", "-c", "/usr/share/nginx/html/env.production.sh && nginx -g \"daemon off;\""]
