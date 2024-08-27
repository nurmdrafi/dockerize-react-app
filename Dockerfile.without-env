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

# Installs packages
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