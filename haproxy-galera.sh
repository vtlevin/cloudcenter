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
    wget https://github.com/vtlevin/cloudcenter/edit/master/publicips
    chmod +x publicips
    . publicips
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
# ipArr=(${CliqrTier_siwapp_mariadb_PUBLIC_IP}) # Array of IPs in my tier.
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

sudo mv ~/cliqr.repo /etc/yum.repos.d/
