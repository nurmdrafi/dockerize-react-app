## Dockerize React App Without ENV
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
    
# Copies everything over to Docker filesystem
COPY . .

# Install packages
RUN npm install --force

# Build for production
RUN npm run build

# Stage 2: Serve the project
FROM ubuntu:24.10 AS runner

WORKDIR /app

# Install Node.js
RUN apt update \
    && apt-get install -y curl \
    && curl -fsSL https://deb.nodesource.com/setup_16.x | bash - \
    && apt-get install -y nodejs

# Install `serve` to run the application
RUN npm install -g serve

# Copy build folder
COPY --from=builder /app/build ./build

# Expose the port
EXPOSE 3000

# Run the application
CMD serve -s build -l 3000
```
***Note:-*** We used `ubuntu` base image instead of `alpine` base image to prevent vulnerability issue

### Create Docker Compose
```yaml
services:
  dockerize-react-app:
    container_name: dockerize-react-app
    image: dockerize-react-app
    restart: unless-stopped
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "5000:3000"
```

### Commands
```sh
# Run specific docker compose file
docker compose up -f ${filename} up -d
```

### Resource
- [How to implement runtime env variables with create-react-app, Docker, and Nginx](https://medium.com/free-code-camp/how-to-implement-runtime-environment-variables-with-create-react-app-docker-and-nginx-7f9d42a91d70)
- [React script's env variable priority](https://gist.github.com/csandman/f17d2c9f19b396328cec4254b9a77995)