#!/bin/bash

read -p "Enter your VPS IP address: " vps_ip
read -p "Enter the username on the VPS (e.g., TheDexon): " username
read -s -p "Enter the password for $username for initial access: " initial_password
echo
read -s -p "Enter the sudo password for $username on the server: " sudo_password
echo

if [ ! -f ~/.ssh/id_ed25519 ]; then
    echo "Generating a new SSH key..."
    ssh-keygen -t ed25519 -C "$username@$vps_ip" -f ~/.ssh/id_ed25519 -N ""
    echo "Private key saved in: ~/.ssh/id_ed25519"
    echo "Public key saved in: ~/.ssh/id_ed25519.pub"
else
    echo "SSH key already exists in ~/.ssh/id_ed25519, using it."
fi

echo "Copying public key to the server using the password..."
echo "If it prompts for a password, it is already provided in the script."
sshpass -p "$initial_password" ssh-copy-id -i ~/.ssh/id_ed25519.pub "$username@$vps_ip"

echo "Checking SSH key connection..."
ssh -i ~/.ssh/id_ed25519 "$username@$vps_ip" "echo 'SSH key connection works!'"
if [ $? -ne 0 ]; then
    echo "Error: Could not connect with the key. Check settings and try again."
    exit 1
fi

echo "Configuring server security..."
ssh -i ~/.ssh/id_ed25519 "$username@$vps_ip" << EOF
echo "$sudo_password" | sudo -S echo "Sudo works" || { echo "Error: Incorrect sudo password"; exit 1; }

echo "Disabling password and root login via SSH..."
echo "$sudo_password" | sudo -S sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
echo "$sudo_password" | sudo -S sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
echo "$sudo_password" | sudo -S sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
echo "$sudo_password" | sudo -S sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

echo "$sudo_password" | sudo -S sshd -t
if [ \$? -ne 0 ]; then
    echo "Error in SSH configuration! Reverting changes..."
    echo "$sudo_password" | sudo -S sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    echo "$sudo_password" | sudo -S sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config
    exit 1
fi

echo "Installing Fail2ban..."
echo "$sudo_password" | sudo -S apt update -y
echo "$sudo_password" | sudo -S apt install fail2ban -y

echo "Configuring Fail2ban for SSH protection..."
echo "$sudo_password" | sudo -S bash -c "cat > /etc/fail2ban/jail.local << 'FAIL2BAN_EOF'
[DEFAULT]
bantime  = 3600
maxretry = 5
findtime = 600

[sshd]
enabled  = true
port     = ssh
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 5
bantime  = 3600
FAIL2BAN_EOF"

echo "Restarting services..."
echo "$sudo_password" | sudo -S systemctl restart ssh || { echo "Error: Failed to restart sshd"; exit 1; }
echo "$sudo_password" | sudo -S systemctl restart fail2ban || { echo "Error: Failed to restart fail2ban"; exit 1; }

echo "$sudo_password" | sudo -S systemctl status sshd | grep "Active: active" || { echo "Error: sshd not running after restart"; exit 1; }

echo "$sudo_password" | sudo -S systemctl is-active sshd >/dev/null 2>&1 && echo "SSHD is running" || echo "Error: SSHD is not running!"
echo "$sudo_password" | sudo -S systemctl is-active fail2ban >/dev/null 2>&1 && echo "Fail2ban is running" || echo "Error: Fail2ban is not running!"

echo "Server secured! Password and root access via SSH disabled."
echo "Fail2ban configured for SSH protection (5 attempts, 1-hour ban)."
exit
EOF

echo "Verifying connection after setup..."
ssh "$username@$vps_ip" "echo 'All works, server secured!'"
if [ $? -eq 0 ]; then
    echo "Success! Server is configured and secured."
    echo "To connect, use: ssh $username@$vps_ip"
    echo "Private key is at ~/.ssh/id_ed25519 - keep it safe for access from other devices."
else
    echo "Error: Could not connect after setup. Check the server."
    exit 1
fi
