#!/bin/bash -x
exec > >(tee -a /var/tmp/haproxy-galera-node-init_$$.log) 2>&1

. /usr/local/osmosix/etc/.osmosix.sh
. /usr/local/osmosix/etc/userenv
. /usr/local/osmosix/service/utils/cfgutil.sh
. /usr/local/osmosix/service/utils/agent_util.sh

# Hack to address the limitation of public ip's nopt being configuired for 5.0 release
cloudType=`cat /usr/local/osmosix/etc/cloud`
if [ $cloudType == 'vmware' ]
then
#    wget https://github.com/vtlevin/cloudcenter/edit/master/publicips.txt
#    chmod +x publicips.txt
#    . publicips.txt
    CliqrTier_siwapp_haproxy_db_PUBLIC_IP=$CliqrTier_siwapp_haproxy_db_IP
    CliqrTier_siwapp_mariadb_PUBLIC_IP=$CliqrTier_siwapp_mariadb_IP
    CliqrTier_siwapp_app_PUBLIC_IP=$CliqrTier_siwapp_app_IP
    CliqrTier_siwapp_load_simulator_PUBLIC_IP=$CliqrTier_siwapp_load_simulator_IP
    #CliqrTier_siwapp_haproxy_app_PUBLIC_IP=$CliqrTier_siwapp_haproxy_app_IP
    CliqrTier_siwapp_apacheproxy_app_PUBLIC_IP=$CliqrTier_siwapp_apacheproxy_app_IP
    cliqrNodePublicIp=$cliqrNodePrivateIp
fi

sudo mv /etc/yum.repos.d/cliqr.repo ~

agentSendLogMessage "Installing haproxy."
sudo yum -y update
sudo yum install -y haproxy

agentSendLogMessage "Configuring haproxy"
sudo su -c 'echo "
#---------------------------------------------------------------------
# Siwapp App Server Backend
#---------------------------------------------------------------------
listen galera 0.0.0.0:3306
balance roundrobin
mode tcp
option tcpka
option mysql-check user haproxy
" >> /etc/haproxy/haproxy.cfg'

# Set internal seperator to ',' since they're comma-delimited lists.
temp_ifs=${IFS}
IFS=','
# nodeArr=(${CliqrTier_siwapp_mariadb_NODE_ID}) # Array of nodes in my tier.
#ipArr=(${CliqrTier_siwapp_mariadb_PUBLIC_IP}) # Array of IPs in my tier.
ipArr=(${CliqrTier_siwapp_mariadb_IP})

# Iterate through list of hosts to add hosts and corresponding IPs to haproxy config file.
host_index=0
for host in $CliqrTier_siwapp_mariadb_HOSTNAME ; do
    sudo su -c "echo 'server ${host} ${ipArr[${host_index}]}:3306 check inter 5s' >> /etc/haproxy/haproxy.cfg"
    sudo su -c "echo '${ipArr[${host_index}]} ${host}' >> /etc/hosts"
    let host_index=${host_index}+1
done
# Set internal separator back to original.
IFS=${temp_ifs}

sudo systemctl start haproxy
sudo systemctl enable haproxy

agentSendLogMessage "Installing Java."
sudo yum install java-1.8.0-openjdk-headless -y

agentSendLogMessage "Installing Tet Pre-reqs."

sudo yum -y install ipset
sudo yum -y install unzip

agentSendLogMessage "Install Tetration Agent"
# Get Tet Script
#curl https://raw.githubusercontent.com/vtlevin/cloudcenter/master/instant-pov_installer_enforcer_linux.sh | sudo bash
curl https://raw.githubusercontent.com/vtlevin/cloudcenter/master/sales5-tetration_installer_enforcer_linux.sh | sudo bash

sudo mv ~/cliqr.repo /etc/yum.repos.d/
