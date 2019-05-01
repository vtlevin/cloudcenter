#!/bin/bash -x

agentSendLogMessage "Install AppD PHP-Agent"

sudo mkdir -p /opt/appd/php-agent/logs

chown -R apache:apache /opt/appd/php-agent
chmod -R 755 /opt/appd/php-agent/logs

echo "198.169.195.125 dangerous2019031501233911.saas.appdynamics.com" >> /etc/hosts

sudo /opt/appd/php-agent/runme.sh

sudo systemctl stop httpd
sudo systemctl start httpd

agentSendLogMessage "App install script complete"
