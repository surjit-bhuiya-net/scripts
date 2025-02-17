#!/bin/bash

# Script to clean and free temporary memory in Linux

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &>/dev/null; then
        echo -e "\033[0;31mError: Command '$1' not found. Please install it and try again.\033[0m"
        exit 1
    fi
}

# Check for required commands
required_commands=(apt-get journalctl awk ps)
for cmd in "${required_commands[@]}"; do
    check_command "$cmd"
done

# Confirmation prompt
echo "This script will clean temporary files, remove unnecessary packages, and free memory."
read -p "Do you want to proceed? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Operation canceled."
    exit 0
fi

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Step 1: Remove unnecessary packages
sudo apt-get autoremove -y --purge
echo -e "${GREEN}Unnecessary packages removed.${NC}"

# Step 2: Autoclean package cache
sudo apt-get autoclean -y
echo -e "${GREEN}Autoclean completed.${NC}"

# Step 3: Remove all files in /tmp directory
sudo rm -rf --preserve-root /tmp/*
echo -e "${GREEN}Temporary files in /tmp directory removed.${NC}"

# Step 4: Clear user cache
rm -rf ~/.cache/*
echo -e "${GREEN}User cache cleared.${NC}"

# Step 5: Clean the package cache
sudo apt-get clean
echo -e "${GREEN}Package cache cleaned.${NC}"

# Step 6: Vacuum system logs older than 7 days
sudo journalctl --vacuum-time=7d
echo -e "${GREEN}System logs older than 7 days vacuumed.${NC}"

# Step 7: Remove old Snap versions (if using Snap)
sudo snap set system refresh.retain=2
sudo snap remove --purge $(snap list --all | awk '/disabled/{print $1" --revision="$3}')
echo -e "${GREEN}Old Snap versions removed.${NC}"

# Step 8: Clear thumbnail cache
rm -rf ~/.cache/thumbnails/*
echo -e "${GREEN}Thumbnail cache cleared.${NC}"

# Step 9: Clear browser caches (Optional: Uncomment if needed)
# rm -rf ~/.mozilla/firefox/*.default-release/cache2/*
# rm -rf ~/.cache/google-chrome/*
# echo -e "${GREEN}Browser caches cleared.${NC}"

# Step 10: Synchronize and drop caches
sudo sync
echo "3" | sudo tee /proc/sys/vm/drop_caches > /dev/null
echo "1" | sudo tee /proc/sys/vm/drop_caches > /dev/null
echo "2" | sudo tee /proc/sys/vm/drop_caches > /dev/null
echo -e "${GREEN}Caches dropped.${NC}"

# Step 11: Clean all user profiles
for user_dir in /home/*; do
    if [ -d "$user_dir/.cache" ]; then
        sudo rm -rf "$user_dir/.cache/*"
        echo -e "${GREEN}Cache cleared for $user_dir.${NC}"
    fi
    if [ -d "$user_dir/.cache/thumbnails" ]; then
        sudo rm -rf "$user_dir/.cache/thumbnails/*"
        echo -e "${GREEN}Thumbnail cache cleared for $user_dir.${NC}"
    fi
done

# Step 12: List orphaned processes
echo -e "${GREEN}Listing orphaned processes:${NC}"
ps -eo ppid,pid,cmd | awk '$1 == 1 {print $2, $3}'

# Step 13: Kill orphaned processes (Optional: Uncomment if needed)
# ps -eo ppid,pid,cmd | awk '$1 == 1 {print $2}' | xargs -r kill -9
# echo -e "${GREEN}Orphaned processes terminated.${NC}"

# Step 14: Check disk space usage
df -h
echo -e "${GREEN}Cleanup completed successfully.${NC}"
