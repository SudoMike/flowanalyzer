# Copyright 2016, Manito Networks, LLC. All rights reserved.
# Install script for ELK 2.x
set -ex

base_dir=$(realpath $(dirname $0)/..)

# Get installation path
export flow_analyzer_dir=$base_dir/Install

# Ensure we have the permissions we need to execute scripts
chmod -R +x $base_dir

# Copy example netflow_options_default.py to real netflow_options.py
echo "Copy example netflow_options_default.py to real netflow_options.py"
cp $base_dir/Python/netflow_options_default.py $base_dir/Python/netflow_options.py

# Set timezone to UTC
echo "Set timezone to UTC"
timedatectl set-timezone UTC

# Install dependencies
echo "Install system dependencies"
apt-get update
apt-get -y install ntp curl apt-transport-https python3-pip

# Resolving Python dependencies
echo "Install Python dependencies"
#pip install --upgrade setuptools
pip install --upgrade pip
pip install -r $flow_analyzer_dir/requirements.txt
pip install --upgrade elasticsearch-curator

# Setting up the Netflow v5 service
echo "Setting up the Netflow v5 service"
echo "[Unit]" >> /etc/systemd/system/netflow_v5.service
echo "Description=Netflow v5 listener service" >> /etc/systemd/system/netflow_v5.service
echo "After=network.target elasticsearch.service kibana.service" >> /etc/systemd/system/netflow_v5.service
echo "[Service]" >> /etc/systemd/system/netflow_v5.service
echo "Type=simple" >> /etc/systemd/system/netflow_v5.service
echo "ExecStart=/usr/bin/python3 $base_dir/Python/netflow_v5.py" >> /etc/systemd/system/netflow_v5.service
echo "Restart=on-failure" >> /etc/systemd/system/netflow_v5.service
echo "RestartSec=30" >> /etc/systemd/system/netflow_v5.service
echo "StandardOutput=journal" >> /etc/systemd/system/netflow_v5.service
echo "[Install]" >> /etc/systemd/system/netflow_v5.service
echo "WantedBy=multi-user.target" >> /etc/systemd/system/netflow_v5.service

# Register new services created above
echo "Register new services created above"
systemctl daemon-reload

# Set the Netflow services to automatically start
echo "Set the collector services to automatically start"
systemctl enable netflow_v5

# Set the NTP service to automatically start
echo "Set the NTP service to automatically start"
systemctl enable ntp

# Prune old indexes
#echo "curator --host 127.0.0.1 delete indices --older-than 30 --prefix "flow" --time-unit days  --timestring '%Y-%m-%d'" >> /etc/cron.daily/index_prune
echo "curator --config $flow_analyzer_dir/curator_config.yml $flow_analyzer_dir/curator_actions.yml" >> /etc/cron.daily/index_prune
chmod +x /etc/cron.daily/index_prune