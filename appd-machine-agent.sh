#!/bin/bash -x

sudo rpm -ivh /opt/appd/machine-agent/appdynamics-machine-agent-4.5.9.2096.x86_64.rpm

systemctl stop appdynamics-machine-agent

sudo curl -o /opt/appdynamics/machine-agent/conf/controller-info.xml https://raw.githubusercontent.com/vtlevin/cloudcenter/master/controller-info-xml

systemctl restart appdynamics-machine-agent
