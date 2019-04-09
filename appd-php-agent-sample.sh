#!/bin/bash

APPD_PHP_PATH=/opt/remi/php56/root/bin
APPD_CONF_ACCOUNT_NAME='dangerous2019031501233911'
APPD_CONF_ACCESS_KEY='xhibem365na4'
APPD_CONF_CONTROLLER_HOST='dangerous2019031501233911.saas.appdynamics.com'
APPD_CONF_CONTROLLER_PORT='443'
APPD_CONF_SSL_ENABLED='true'
APPD_CONF_APP='SIWAPP'
APPD_CONF_TIER='AppTier'
AGENT_LOCATION="/opt/appdynamics/php-agent"

APPD_PHP_PATH=/opt/remi/php56/root/bin sudo bash ./runme.sh

systemctl restart httpd
