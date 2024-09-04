## Dockerize React App With ENV Using Serve

```Dockerfile
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
COPY --from=base /root/.nvm /home/reactjs/.nvm

# Set Node.js environment for non-root user
ENV NODE_VERSION="22.0.0"
ENV NVM_DIR="/home/reactjs/.nvm"
ENV PATH="$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH"

# Install `serve` to run the application.
RUN npm install -g serve

# Copy build files from builder stage
COPY --from=builder /app/build .

# Copy the shell script and env file
COPY ./env.sh .
COPY .env.example .

# Make shell script executable
RUN chmod +x env.sh

# Create a non-root user and set ownership
RUN groupadd -g 1001 nodejs \
    && useradd -u 1001 -g nodejs -m -s /bin/bash reactjs \
    && chown -R reactjs:nodejs /app

# Ensure Node.js is accessible for the non-root user
RUN bash -c "chown -R reactjs:nodejs /home/reactjs/.nvm"   

# Switch to non-root user
USER reactjs

# Default port exposure
EXPOSE 3000

# Run
CMD ["/bin/sh", "-c", "/app/env.sh && serve -s . -l 3000"]
```

***Note:-*** We used `ubuntu` base image instead of `alpine` base image to prevent vulnerability issue

### Manage ENV
- We used `env-cmd` package for manage ENV for specific stage
- Follow => https://dev.to/jam3/managing-env-variables-for-provisional-builds-h37

#### Create Docker Compose File
```yaml
services:
  dockerize-react-app:
    container_name: dockerize-react-app
    image: dockerize-react-app
    restart: unless-stopped
    build:
      context: .
      dockerfile: Dockerfile
    env_file:
      # - .env.local
      # - .env.example
    ports:
      - "5000:80"
```

#### Create Shell Script
This shell script generates a JavaScript file (`env-config.js`) that defines a `window._env_` object, containing environment variables and their values. 

```sh
#!/bin/sh
echo "window._env_ = {" > ./env-config.js
awk -F '=' '{ print $1 ": \"" (ENVIRON[$1] ? ENVIRON[$1] : $2) "\"," }' ./.env.example >> ./env-config.js
echo "}" >> ./env-config.js
```

#### Include this script on index.html head tag
```html
<script src="%PUBLIC_URL%/env-config.js"></script>
```

#### Update package.json scripts
```json
 "scripts": {
    "dev": "chmod +x ./env.local.sh && ./env.local.sh && cp env-config.js ./public/ && react-scripts start",
    "start": "react-scripts start",
    "build": "react-scripts build",
    "build:docker": "env-cmd -f .env.example react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
```

#### Commands
```sh
# Run specific docker compose file
docker compose up -f ${filename} up -d
```

### Resource
- [How to implement runtime env variables with create-react-app, Docker, and Nginx](https://medium.com/free-code-camp/how-to-implement-runtime-environment-variables-with-create-react-app-docker-and-nginx-7f9d42a91d70)
- [React script's env variable priority order](https://create-react-app.dev/docs/adding-custom-environment-variables/#what-other-env-files-can-be-used)
- [Managing .env variables for provisional builds with Create React App](https://dev.to/jam3/managing-env-variables-for-provisional-builds-h37)