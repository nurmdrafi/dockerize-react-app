# Stage 1: Setup Node.js with NVM ===>
FROM ubuntu:24.10 AS base

# Set working directory
WORKDIR /app

# Install dependencies
RUN apt-get update && \
    apt-get install -y curl

# Install NVM
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

# Install Node.js
RUN bash -c "source ~/.nvm/nvm.sh \
    && nvm install 22.0.0 \
    && nvm use 22.0.0 \
    && nvm alias default 22.0.0"

# Make Node.js available globally by copying it to the system-wide path
ENV NODE_VERSION="22.0.0"
ENV NVM_DIR="/root/.nvm"
ENV PATH="$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH"

# Stage 2: Install node packages ===>
FROM ubuntu:24.10 AS deps

# Set working directory
WORKDIR /app

# Copy NVM from the base stage
COPY --from=base /root/.nvm /root/.nvm

# Set Node.js environment
ENV NVM_DIR="/root/.nvm"
ENV NODE_VERSION="22.0.0"
ENV PATH="$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH"

# Copy package json
COPY package*.json ./

# Install packages
RUN npm install --force

# Stage 3: Build the project ===>
FROM ubuntu:24.10 AS builder

# Set working directory
WORKDIR /app

# Copy NVM from the base stage
COPY --from=base /root/.nvm /root/.nvm

# Set Node.js environment
ENV NVM_DIR="/root/.nvm"
ENV NODE_VERSION="22.0.0"
ENV PATH="$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH"

# Copy necessary files
COPY . .
COPY --from=deps /app/node_modules ./node_modules

# Build for docker
RUN npm run build:docker

# Stage 4: Serve the project ===>
FROM ubuntu:24.10 AS runner

WORKDIR /app

# Copy NVM from the base stage for non-root user
COPY --from=base /root/.nvm /home/nextjs/.nvm

# Set Node.js environment for non-root user
ENV NODE_VERSION="22.0.0"
ENV NVM_DIR="/home/nextjs/.nvm"
ENV PATH="$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH"

# Install `serve` to run the application.
RUN npm install -g serve

# Copy build files
COPY --from=builder /app/build .

# Copy the shell script and env file
COPY ./env.sh .
COPY .env.example .

# Make shell script executable
RUN chmod +x env.sh

# Default port exposure
EXPOSE 3000

# Run
CMD ["/bin/sh", "-c", "/app/env.sh && serve -s . -l 3000"]