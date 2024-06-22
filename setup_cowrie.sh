#!/bin/bash

# Check if the IP address is provided as an argument
if [ -z "$1" ]; then
  echo "Usage: $0 <WAZUH_MANAGER_IP>"
  exit 1
fi

# Assign the first argument to the WAZUH_MANAGER variable
WAZUH_MANAGER_IP=$1

# Set the WAZUH_AGENT_NAME (change as needed)
WAZUH_AGENT_NAME='bn-cwr'

# Update and upgrade the system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y git python3-virtualenv libssl-dev libffi-dev build-essential wget

# Clone the Cowrie repository
git clone https://github.com/cowrie/cowrie.git /opt/cowrie

# Create a virtual environment for Cowrie
cd /opt/cowrie
python3 -m virtualenv cowrie-env

# Activate the virtual environment
source cowrie-env/bin/activate

# Install required Python packages
pip install --upgrade pip
pip install -r requirements.txt

# Copy the template configuration file
cp /opt/cowrie/etc/cowrie.cfg.dist /opt/cowrie/etc/cowrie.cfg

# Update the configuration file
sed -i 's/#listen_port = 2222/listen_port = 2222/' /opt/cowrie/etc/cowrie.cfg

# Create a systemd service file for Cowrie
cat <<EOF | sudo tee /etc/systemd/system/cowrie.service
[Unit]
Description=Cowrie SSH Honeypot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/cowrie
ExecStart=/opt/cowrie/cowrie-env/bin/python3 /opt/cowrie/bin/cowrie start
ExecStop=/opt/cowrie/cowrie-env/bin/python3 /opt/cowrie/bin/cowrie stop
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd to recognize the new service
sudo systemctl daemon-reload

# Start the Cowrie service
sudo systemctl start cowrie

# Enable the service to start on boot
sudo systemctl enable cowrie

# Download and install the Wazuh agent
wget https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.8.0-1_amd64.deb
sudo WAZUH_MANAGER=$WAZUH_MANAGER_IP WAZUH_AGENT_NAME='bn-cwr' dpkg -i ./wazuh-agent_4.8.0-1_amd64.deb

# Cleanup
rm ./wazuh-agent_4.8.0-1_amd64.deb