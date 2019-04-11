#!/bin/bash -x

sudo curl -o /etc/appdynamics/machine-agent/controller-info.xml https://raw.githubusercontent.com/vtlevin/cloudcenter/master/controller-info.xml
sudo curl -o /etc/sysconfig/appdynamics-machine-agent https://raw.githubusercontent.com/vtlevin/cloudcenter/master/appdynamics-machine-agent 
sudo rpm -ivh /opt/appd/machine-agent/appdynamics-machine-agent-4.5.9.2096.x86_64.rpm


