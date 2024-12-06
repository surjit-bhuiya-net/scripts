#!/bin/bash

# Script to clean and free temporary memory in Linux

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &>/dev/null; then
        echo "Error: Command '$1' not found. Please install it and try again."
        exit 1
    fi
}

# Check for required commands
required_commands=(apt-get journalctl awk ps)
for cmd in "${required_commands[@]}"; do
    check_command "$cmd"
done

echo "This script will clean temporary files, remove unnecessary packages, and free memory."
read -p "Do you want to proceed? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Operation canceled."
    exit 0
fi

echo "Starting cleanup..."

# Step 1: Remove unnecessary packages
sudo apt-get autoremove -y
echo "Unnecessary packages removed."

# Step 2: Autoclean package cache
sudo apt-get autoclean -y
echo "Autoclean completed."

# Step 3: Remove all files in /tmp directory
sudo rm -rf /tmp/*
echo "Temporary files in /tmp directory removed."

# Step 4: Clear user cache
rm -rf ~/.cache/*
echo "User cache cleared."

# Step 5: Clean the package cache
sudo apt-get clean
echo "Package cache cleaned."

# Step 6: Vacuum system logs older than 7 days
sudo journalctl --vacuum-time=7d
echo "System logs older than 7 days vacuumed."

# Step 7: Synchronize and drop caches
sudo sync
echo "3" | sudo tee /proc/sys/vm/drop_caches
echo "1" | sudo tee /proc/sys/vm/drop_caches
echo "2" | sudo tee /proc/sys/vm/drop_caches
echo "Caches dropped."

# Step 8: List orphaned processes
echo "Listing orphaned processes:"
ps -eo ppid,pid,cmd | awk '$1 == 1 {print $2, $3}'

echo "Cleanup completed successfully."

