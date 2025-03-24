#!/bin/bash

# Define variables
IMAGE_NAME="dnif/pico"
CONTAINER_NAME="dnif_pico"
IMAGE_TAR="/var/tmp/dnif_pico.tar"
COMPOSE_FILE="/DNIF/PICO/docker-compose.yaml"  # Update with the correct path
DOCKER_HUB_API="https://registry.hub.docker.com/v2/repositories/dnif/pico/tags"

# Function to install skopeo if not installed
install_skopeo() {
    if ! command -v skopeo &>/dev/null; then
        echo "Skopeo not found. Installing..."
        sudo apt update && sudo apt install -y skopeo
    else
        echo "Skopeo is already installed."
    fi
}

# Function to check network connectivity
check_network() {
    echo "Checking network connectivity..."
    if ! ping -c 2 8.8.8.8 >/dev/null 2>&1; then
        echo "Network is down! Unable to pull the latest image."
        exit 1
    fi
}

# Ensure Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "Docker is not running! Please start Docker and try again."
    exit 1
fi

# Fetch the latest image tag dynamically
echo "Fetching the latest image tag for $IMAGE_NAME..."
LATEST_TAG=$(curl -s $DOCKER_HUB_API | jq -r '.results[].name' | sort -Vr | head -n1)

# Validate if we got a valid tag
if [[ -z "$LATEST_TAG" ]]; then
    echo "Failed to fetch the latest image tag. Exiting..."
    exit 1
fi

echo "Latest image tag found: $LATEST_TAG"

# Check if the container is running
if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
    echo "Container '$CONTAINER_NAME' is running. No update needed."
    exit 0
fi

# Check network before pulling the image
check_network

# Try to pull the latest image using Docker
echo "Trying to pull the latest image: $IMAGE_NAME:$LATEST_TAG..."
if docker pull "$IMAGE_NAME:$LATEST_TAG" | tee pull_output.log; then
    echo "Docker pull successful."
else
    echo "Docker pull failed! Trying alternative method using Skopeo..."
    
    # Install skopeo if missing
    install_skopeo

    # Try to download the image using Skopeo
    if skopeo copy docker://docker.io/$IMAGE_NAME:$LATEST_TAG docker-archive:$IMAGE_TAR; then
        echo "Skopeo download successful. Loading image into Docker..."
        docker load -i $IMAGE_TAR
    else
        echo "Skopeo also failed! Exiting..."
        exit 1
    fi
fi

# Bring Docker down and up again with the updated image
echo "Bringing Docker down..."
docker-compose -f "$COMPOSE_FILE" down


# Update docker-compose.yaml with the new tag
echo "Updating docker-compose.yaml with the latest image tag..."
sed -i "s|image: $IMAGE_NAME:.*|image: $IMAGE_NAME:$LATEST_TAG|" "$COMPOSE_FILE"


echo "Bringing Docker up with the updated image..."
docker-compose -f "$COMPOSE_FILE" up -d

# Cleanup
rm -f pull_output.log
rm -f $IMAGE_TAR

echo "Update complete! The service is now running with $IMAGE_NAME:$LATEST_TAG"

