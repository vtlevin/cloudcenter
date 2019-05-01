#!/bin/bash -x

agentSendLogMessage "Install AppD PHP-Agent"

sudo mkdir -p /opt/appd/php-agent/logs

chown -R apache:apache /opt/appd/php-agent
chmod -R 755 /opt/appd/php-agent/logs

echo "198.169.195.125 dangerous2019031501233911.saas.appdynamics.com" >> /etc/hosts

#sudo /opt/appd/php-agent/runme.sh
sudo APPD_PHP_PATH=/opt/remi/php56/root/bin rpm -i appdynamics-php-agent-4.5.0.0-1.x86_64.rpm

sudo systemctl stop httpd
sudo systemctl start httpd

agentSendLogMessage "App install script complete"
