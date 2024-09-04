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

# Stage 2: Install npm packages and Build the project
FROM ubuntu:24.10 AS deps

# Set working directory
WORKDIR /app

# Copy NVM from the base stage
COPY --from=base /root/.nvm /root/.nvm

# Set Node.js environment
ENV NVM_DIR="/root/.nvm"
ENV NODE_VERSION="22.0.0"
ENV PATH="$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH"

# Copies everything over to Docker filesystem
COPY . .

# Install npm packages and build
RUN npm install --force \
    && npm run build

# Stage 3: Serve the project ===>
FROM ubuntu:24.10 AS runner

WORKDIR /app

# Copy NVM and Node.js binaries for non-root user
COPY --from=base /root/.nvm /home/reactjs/.nvm

# Set Node.js environment
ENV NODE_VERSION="22.0.0"
ENV NVM_DIR="/home/reactjs/.nvm"
ENV PATH="$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH"

# Install `serve` to run the application
RUN npm install -g serve

# Create a non-root user and set ownership
RUN groupadd -g 1001 nodejs \
    && useradd -u 1001 -g nodejs -m -s /bin/bash reactjs \
    && chown -R reactjs:nodejs /app

# Ensure Node.js is accessible for the non-root user
RUN bash -c "chown -R reactjs:nodejs /home/reactjs/.nvm"    

# Copy build folder
COPY --from=builder /app/build ./build

# Switch to non-root user
USER reactjs

# Expose the port
EXPOSE 3000

# Run the application
CMD serve -s build -l 3000