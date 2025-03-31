#!/bin/bash

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root (sudo)"
    exit 1
fi

# Prompt for new username
echo "Enter the new username: "
read username

# Check if user already exists
if id "$username" > /dev/null 2>&1; then
    echo "User $username already exists!"
    exit 1
fi

# Prompt for password
echo "Enter password for $username: "
read -s password
echo
echo "Confirm password: "
read -s password_confirm
echo

# Check if passwords match
if [ "$password" != "$password_confirm" ]; then
    echo "Passwords do not match!"
    exit 1
fi

# Create user with home directory
useradd -m -s /bin/bash "$username"

# Set password
echo "$username:$password" | chpasswd

# Add user to sudo group
usermod -aG sudo "$username"

# Check if operation was successful
if [ $? -eq 0 ]; then
    echo "User $username successfully created and added to sudo group!"
    echo "Now $username has root privileges via sudo."
else
    echo "An error occurred while creating the user."
    exit 1
fi
