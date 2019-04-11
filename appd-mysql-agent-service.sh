#!/bin/bash -x

agentSendLogMessage "Installing Appd MYSQL-Agent."

sudo java -jar /opt/appd/mysql-agent/db-agent.jar

agentSendLogMessage "App install script complete"
