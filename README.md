- [How to implement runtime environment variables with create-react-app, Docker, and Nginx](https://medium.com/free-code-camp/how-to-implement-runtime-environment-variables-with-create-react-app-docker-and-nginx-7f9d42a91d70)

### Dockerize React Project
## Without ENV
```Dockerfile
# Stage 1: Install dependencies and Build the project
FROM ubuntu:24.10 AS builder

# Set working directory
WORKDIR /app

# Install Node.js
RUN apt update \
    && apt-get install -y curl \
    && curl -fsSL https://deb.nodesource.com/setup_16.x | bash - \
    && apt-get install -y nodejs
    
# Copies everything over to Docker environment
COPY . .

# Installs all node packages
RUN npm install --force

# Build for production.
RUN npm run build

# Stage 2: Serve the project
FROM ubuntu:24.10 AS runner

WORKDIR /app

# Install Node.js
RUN apt update \
    && apt-get install -y curl \
    && curl -fsSL https://deb.nodesource.com/setup_16.x | bash - \
    && apt-get install -y nodejs

# Install `serve` to run the application.
RUN npm install -g serve

# Copy build files
COPY --from=builder /app/build ./build

# Default port exposure
EXPOSE 3000

# Run application
CMD serve -s build -l 3000
```
***Note:-*** We used `ubuntu` base image instead of `alpine` base image to prevent vulnerability issue

## Dynamic ENV (Method 1)
```Dockerfile
# Stage 1: Install dependencies
FROM ubuntu:24.10 AS deps

# set working directory
WORKDIR /app

# Install Node.js
RUN apt update \
    && apt-get install -y curl \
    && curl -fsSL https://deb.nodesource.com/setup_16.x | bash - \
    && apt-get install -y nodejs

# Copy
COPY package.json package-lock.json ./

# Installs all node packages
RUN npm ci --force

# Stage 2: Build the project
FROM ubuntu:24.10 AS builder

WORKDIR /app

# Install Node.js
RUN apt update \
    && apt-get install -y curl \
    && curl -fsSL https://deb.nodesource.com/setup_16.x | bash - \
    && apt-get install -y nodejs

# Copy
COPY . .
COPY --from=deps /app/node_modules ./node_modules

# Build for production
RUN npm run safe-build

# Stage 3: Serve the project
FROM nginx:alpine AS runner

# Nginx config
RUN rm -rf /etc/nginx/conf.d
COPY conf /etc/nginx

# Copy build files
COPY --from=builder /app/build /usr/share/nginx/html/

# Default port exposure
EXPOSE 80

# Copy .env file and shell script to container
WORKDIR /usr/share/nginx/html
COPY ./env.production.sh .
COPY .env.production .

# Make our shell script executable
RUN chmod +x env.production.sh

# Start Nginx server
CMD ["/bin/sh", "-c", "/usr/share/nginx/html/env.production.sh && nginx -g \"daemon off;\""]
```

#### Docker compose
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
      - .env.local
    ports:
      - "5000:80"
```

#### For local development
```sh
# .env.development
REACT_APP_API_BASE_URL=https://test.barikoimaps.dev
```

#### For docker build
```sh
# .env.production
REACT_APP_API_BASE_URL=
```
#### This script generate env-config.js for production
```sh
# .env.production.sh
#!/bin/sh
echo "window._env_ = {" > ./env-config.js
awk -F '=' '{ print $1 ": \"" (ENVIRON[$1] ? ENVIRON[$1] : $2) "\"," }' ./.env.production >> ./env-config.js
echo "}" >> ./env-config.js
```

#### This script generate env-config.js for development
```sh
# .env.development.sh
#!/bin/sh
# line endings must be \n, not \r\n !
echo "window._env_ = {" > ./env-config.js
awk -F '=' '{ print $1 ": \"" (ENVIRON[$1] ? ENVIRON[$1] : $2) "\"," }' ./.env.development >> ./env-config.js
echo "}" >> ./env-config.js
```
#### Include this script on index.html head tag
```html
<script src="%PUBLIC_URL%/env-config.js"></script>
```

#### Update package.json scripts
```json
  "scripts": {
    "dev": "chmod +x ./env.development.sh && ./env.development.sh && cp env-config.js ./public/ && react-scripts start",
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject",
  },
```