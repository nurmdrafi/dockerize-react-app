# Stage 1: Install dependencies
FROM ubuntu:24.10 AS deps

# Set working directory
WORKDIR /app

# Set APT retries and timeout + Install curl, and Node.js
RUN echo 'Acquire::Retries "5";' > /etc/apt/apt.conf.d/80-retries \
    && echo 'Acquire::http::Timeout "120";' >> /etc/apt/apt.conf.d/80-retries \
    && apt-get update \
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

# Set APT retries and timeout + Install curl, and Node.js
RUN echo 'Acquire::Retries "5";' > /etc/apt/apt.conf.d/80-retries \
    && echo 'Acquire::http::Timeout "120";' >> /etc/apt/apt.conf.d/80-retries \
    && apt-get update \
    && apt-get install -y curl \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

# Copies everything over to Docker filesystem
COPY . .
COPY --from=deps /app/node_modules ./node_modules

# Build for staging
RUN npm run build:staging

# Stage 3: Serve the project
FROM ubuntu:24.10 AS runner

WORKDIR /app

# Set APT retries and timeout + Install curl, and Node.js
RUN echo 'Acquire::Retries "5";' > /etc/apt/apt.conf.d/80-retries \
    && echo 'Acquire::http::Timeout "120";' >> /etc/apt/apt.conf.d/80-retries \
    && apt-get update \
    && apt-get install -y curl \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

# Install `serve` to run the application.
RUN npm install -g serve

# Copy build files
COPY --from=builder /app/build .

# Copy the shell script to replace environment variables
COPY ./env.staging.sh .

# Make shell script executable
RUN chmod +x env.staging.sh
COPY .env.staging .

# Default port exposure
EXPOSE 3000

# Run
CMD ["/bin/sh", "-c", "/app/env.staging.sh && serve -s . -l 3000"]
