## Dockerize React App With ENV Using Serve

```Dockerfile
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

# Copy all and node_modules
COPY . .
COPY --from=deps /app/node_modules ./node_modules

# Build for docker
RUN npm run build:docker

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

# Copy the shell script and env file
COPY ./env.sh .
COPY .env.example .

# Make shell script executable
RUN chmod +x env.sh

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
- [React script's env variable priority](https://gist.github.com/csandman/f17d2c9f19b396328cec4254b9a77995)
- [Managing .env variables for provisional builds with Create React App](https://dev.to/jam3/managing-env-variables-for-provisional-builds-h37)