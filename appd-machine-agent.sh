#!/bin/bash -x

. /usr/local/osmosix/etc/.osmosix.sh
. /usr/local/osmosix/etc/userenv
. /usr/local/osmosix/service/utils/cfgutil.sh
. /usr/local/osmosix/service/utils/agent_util.sh

sudo rpm -ivh /opt/appd/machine-agent/appdynamics-machine-agent-4.5.9.2096.x86_64.rpm

systemctl stop appdynamics-machine-agent

sudo curl -o /opt/appdynamics/machine-agent/conf/controller-info.xml https://raw.githubusercontent.com/vtlevin/cloudcenter/master/controller-info-xml

#for host in $cliqrNodeHostname; do
#    sudo sed -i '/\<tier-name\>App-Tier\<\/tier-name\>/a \<node-name\>'${host}'\<\/node-name\>' /opt/appdynamics/machine-agent/conf/controller-info.xml
#done   
  
systemctl restart appdynamics-machine-agent
