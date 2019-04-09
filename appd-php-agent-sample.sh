#!/bin/bash

APPD_PHP_PATH=/opt/remi/php56/root/bin
APPD_CONF_ACCOUNT_NAME='dangerous2019031501233911'
APPD_CONF_ACCESS_KEY='xhibem365na4'
APPD_CONF_CONTROLLER_HOST='dangerous2019031501233911.saas.appdynamics.com'
APPD_CONF_CONTROLLER_PORT='443'
APPD_CONF_SSL_ENABLED='true'
APPD_CONF_APP='SIWAPP'
APPD_CONF_TIER='AppTier'
AGENT_LOCATION="/opt/appd/php-agent"

#sudo mkdir -p /opt/appdynamics/php-agent
#sudo mkdir -p /opt/appdynamics/php-agent/logs

#chown -R apache:apache /opt/appdynamics/php-agent
#chmod -R 755 /opt/appdynamics/php-agent/logs
#chmod +x runme.sh
#chmod +x installVars

APPD_PHP_PATH=/opt/remi/php56/root/bin rpm -i appdynamics-php-agent-4.5.0.0-1.x86_64.rpm

sudo systemctl stop httpd
sudo systemctl start httpd
