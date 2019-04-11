#!/bin/bash -x

agentSendLogMessage "Installing Appd MYSQL-Agent."

sudo java -jar /opt/appd/mysql-agent/db-agent.jar

#!/bin/bash
#
# Init file for AppDynamics Database Agent
#
# chkconfig: 2345 60 25
# description: database agent for AppDynamics

#CHANGE ME: Set to the Java install directory
JAVA="/usr/lib/jvm"

#CHANGE ME: Set to the agent's install directory
AGENT_HOME="/opt/appd/mysql-agent"
AGENT="$AGENT_HOME/db-agent.jar"

#CHANGE ME: Set to a name that is unique to the Controller - required when a machine agent is
#also running on the same hardware
AGENT_OPTIONS="appdynamics.agent.uniqueHostId='unique host ID'"

# Agent Options
AGENT_OPTIONS=""
#AGENT_OPTIONS="$AGENT_OPTIONS -Dappdynamics.agent.logging.dir="
#AGENT_OPTIONS="$AGENT_OPTIONS -Dmetric.http.listener=true | false
#AGENT_OPTIONS="$AGENT_OPTIONS -Dmetric.http.listener.port=<port>"
#AGENT_OPTIONS="$AGENT_OPTIONS -Dserver.name=<hostname>"


start()
{
nohup $JAVA $AGENT_OPTIONS -Xmx1536m -jar $AGENT > /dev/null 2>&1 &
}

stop()
{
ps -opid,cmd |egrep "[0-9]+ $JAVA.*db-agent" | awk '{print $1}' | xargs --no-run-if-empty kill -9
}

case "$1" in
start)
start
;;

stop)
stop
;;

restart)
stop
start
;;
*)
echo "Usage: $0 start|stop|restart"
esac


agentSendLogMessage "App install script complete"
