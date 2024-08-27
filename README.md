### Dockerize React App
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

#### Create Docker Compose File
- Use `.env.development` for local development
- Use `.env.production` for docker hub
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
      # - .env.development
      # - .env.production
    ports:
      - "5000:80"
```
#### Create Shell Script
This shell script generates a JavaScript file (`env-config.js`) that defines a `window._env_` object, containing environment variables and their values. 
```sh
#!/bin/sh
# .env.production.sh
echo "window._env_ = {" > ./env-config.js
awk -F '=' '{ print $1 ": \"" (ENVIRON[$1] ? ENVIRON[$1] : $2) "\"," }' ./.env.production >> ./env-config.js
echo "}" >> ./env-config.js
```

```sh
# .env.development.sh
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

#### Commands
```sh
# Run specific docker compose file
docker compose up -f ${filename} up -d
```

### Resource
- [How to implement runtime env variables with create-react-app, Docker, and Nginx](https://medium.com/free-code-camp/how-to-implement-runtime-environment-variables-with-create-react-app-docker-and-nginx-7f9d42a91d70)
- [React script's env variable priority](https://gist.github.com/csandman/f17d2c9f19b396328cec4254b9a77995)