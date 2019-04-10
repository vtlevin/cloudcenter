#!/bin/bash -x

agentSendLogMessage "Installing Appd Machine-Agent."

/opt/appd/machine-agent/jre/bin/java -jar 
/opt/aapd/machine-agent/machineagent.jar

agentSendLogMessage "App install script complete"
