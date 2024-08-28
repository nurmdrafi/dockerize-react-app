## Dockerize React App With ENV Using Serve

```Dockerfile
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

# Build for staging
RUN npm run build:staging

# Stage 3: Serve the project
FROM ubuntu:24.10 AS runner

WORKDIR /app

# Install Node.js
RUN apt update \
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
      # - .env.staging
      # - .env.production
    ports:
      - "5000:80"
```

#### Create Shell Script
This shell script generates a JavaScript file (`env-config.js`) that defines a `window._env_` object, containing environment variables and their values. 

```sh
#!/bin/sh
echo "window._env_ = {" > ./env-config.js
awk -F '=' '{ print $1 ": \"" (ENVIRON[$1] ? ENVIRON[$1] : $2) "\"," }' ./.env.staging >> ./env-config.js
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
    "build:staging": "env-cmd -f .env.staging react-scripts build",
    "build:production": "env-cmd -f .env.production react-scripts build",
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
- [React script's env variable priority](https://gist.github.com/csandman/f17d2c9f19b396328cec4254b9a77995)
- [Managing .env variables for provisional builds with Create React App](https://dev.to/jam3/managing-env-variables-for-provisional-builds-h37)