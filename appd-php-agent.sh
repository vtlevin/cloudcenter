#!/bin/bash -x

agentSendLogMessage "Install AppD PHP-Agent"

APPD_PHP_PATH='APPD_PHP_PATH=/opt/remi/php56/root/bin'
APPD_CONF_ACCOUNT_NAME='APPD_CONF_ACCOUNT_NAME=dangerous2019031501233911'
APPD_CONF_ACCESS_KEY='APPD_CONF_ACCESS_KEY=xhibem365na4'
APPD_CONF_CONTROLLER_HOST='APPD_CONF_CONTROLLER_HOST=dangerous2019031501233911.saas.appdynamics.com'
APPD_CONF_CONTROLLER_PORT='APPD_CONF_CONTROLLER_PORT=443'
APPD_CONF_SSL_ENABLED='APPD_CONF_SSL_ENABLED=true'
APPD_CONF_APP='APPD_CONF_APP=SIWAPP=HYBRID'
APPD_CONF_TIER='APPD_CONF_TIER=App-Tier'

#sudo mkdir -p /opt/appd/php-agent
#sudo mkdir -p /opt/appd/php-agent/logs

chown -R apache:apache /opt/appd/php-agent
chmod -R 755 /opt/appd/php-agent/logs
#chmod +x runme.sh
#chmod +x installVars

echo "198.169.195.125 dangerous2019031501233911.saas.appdynamics.com" >> /etc/hosts

source /opt/appd/php-agent/installVars

sudo /opt/appd/php-agent/$APPD_PHP_PATH $APPD_CONF_ACCOUNT_NAME $APPD_CONF_ACCESS_KEY $APPD_CONF_CONTROLLER_HOST $APPD_CONF_CONTROLLER_PORT $APPD_CONF_SSL_ENABLED $APPD_CONF_APP $APPD_CONF_TIER rpm -i appdynamics-php-agent-4.5.0.0-1.x86_64.rpm

sudo systemctl stop httpd
sudo systemctl start httpd

agentSendLogMessage "App install script complete"
