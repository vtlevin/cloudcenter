#!/bin/bash -x
exec > >(tee -a /var/tmp/haproxy-apache-node-init_$$.log) 2>&1

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
#   . publicips.txt
    CliqrTier_siwapp_haproxy_db_PUBLIC_IP=$CliqrTier_siwapp_haproxy_db_IP
    CliqrTier_siwapp_mariadb_PUBLIC_IP=$CliqrTier_siwapp_mariadb_IP
    CliqrTier_siwapp_app_PUBLIC_IP=$CliqrTier_siwapp_app_IP
    CliqrTier_siwapp_load_simulator_PUBLIC_IP=$CliqrTier_siwapp_load_simulator_IP
    CliqrTier_siwapp_haproxy_app_PUBLIC_IP=$CliqrTier_siwapp_haproxy_app_IP
    cliqrNodePublicIp=$cliqrNodePrivateIp
fi

sudo mv /etc/yum.repos.d/cliqr.repo ~

agentSendLogMessage "Installing Apache Proxy"

sudo yum -y update
sudo yum install -y httpd 

agentSendLogMessage "Configuring Apache Proxy"

sudo su -c 'echo "

LoadModule proxy_module modules/mod_proxy.so
LoadModule proxy_http_module modules/mod_proxy_h
LoadModule lbmethod_byrequests_module modules/mod_lbmethod_byrequests.so
LoadModule proxy_balancer_module modules/mod_proxy_balancer.so

<VirtualHost *:80>
<Proxy balancer://cluster>
</Proxy>
ProxyPreserveHost On
ProxyPass / balancer://cluster/
ProxyPassReverse / balancer://cluster/
</VirtualHost>

" >> /etc/httpd/conf/httpd.conf'

# Set internal separator to ',' since they're comma-delimited lists.
temp_ifs=${IFS}
IFS=','
ipArr=(${CliqrTier_siwapp_app_PUBLIC_IP}) # Array of IPs in my tier.

# Iterate through list of hosts to add hosts and corresponding IPs to haproxy config file.
host_index=0
for host in $CliqrTier_siwapp_app_HOSTNAME ; do
    sed /<Proxy balancer:\/cluster>/a 'BalancerMember http://${ipArr[${host_index}]}:8443' < /etc/httpd/conf/httpd.conf
    #sudo su -c "echo 'BalancerMember http://${ipArr[${host_index}]}:8443' >> /etc/httpd/conf/httpd.conf"
    sudo su -c "echo '${ipArr[${host_index}]} ${host}' >> /etc/hosts"
    let host_index=${host_index}+1
done

# Set internal separator back to original.
IFS=${temp_ifs}

sudo systemctl enable httpd
sudo systemctl start httpd

echo "198.169.195.125 dangerous2019031501233911.saas.appdynamics.com" >> /etc/hosts    

agentSendLogMessage "Installing Java."
sudo yum install java-1.8.0-openjdk-headless -y

agentSendLogMessage "Installing Tet Pre-reqs."

sudo yum -y install ipset
sudo yum -y install unzip

agentSendLogMessage "Install Tetration Agent"
# Get Tet Script
curl https://raw.githubusercontent.com/vtlevin/cloudcenter/master/instant-pov_installer_enforcer_linux.sh | sudo bash

sudo mv ~/cliqr.repo /etc/yum.repos.d/
