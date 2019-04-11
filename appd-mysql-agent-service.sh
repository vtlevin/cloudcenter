#!/bin/bash -x

agentSendLogMessage "Installing Appd MYSQL-Agent."

sudo java -jar /opt/appd/mysql-agent/db-agent.jar
sudo nohup /opt/appd/mysql-agent/jre/bin/.NET - Dbagent.name="appd-mysql-agent" -jar //opt/appd/mysql-agent/db-agent.jar &

agentSendLogMessage "App install script complete"
