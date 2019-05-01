#!/bin/bash -x

agentSendLogMessage "Install AppD PHP-Agent"

sudo mkdir -p /opt/appd/php-agent/logs

chown -R apache:apache /opt/appd/php-agent
chmod -R 755 /opt/appd/php-agent/logs

echo "198.169.195.125 dangerous2019031501233911.saas.appdynamics.com" >> /etc/hosts

sudo /opt/appd/php-agent/runme.sh
#sudo $APPD_CONF_ACCOUNT_NAME $APPD_CONF_ACCESS_KEY $APPD_CONF_CONTROLLER_HOST $APPD_CONF_CONTROLLER_PORT $APPD_CONF_SSL_ENABLED $APPD_CONF_APP $APPD_CONF_TIER $APPD_PHP_PATH rpm -i appdynamics-php-agent-4.5.0.0-1.x86_64.rpm

sudo systemctl stop httpd
sudo systemctl start httpd

agentSendLogMessage "App install script complete"
