#!/usr/bin/env bash
exec > >(tee -a /var/tmp/load-simulator-node-init_$$.log) 2>&1

. /usr/local/osmosix/etc/.osmosix.sh
. /usr/local/osmosix/etc/userenv
. /usr/local/osmosix/service/utils/cfgutil.sh
. /usr/local/osmosix/service/utils/agent_util.sh

sudo mv /etc/yum.repos.d/cliqr.repo ~

sudo yum -y update
sudo yum install -y epel-release
sudo yum install -y python-pip
sudo pip install pip --upgrade
sudo pip install virtualenv

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
    CliqrTier_siwapp_haproxy_app_PUBLIC_IP=$CliqrTier_siwapp_haproxy_app_IP
    cliqrNodePublicIp=$cliqrNodePrivateIp
fi

# Set internal separator to ',' since they're comma-delimited lists.
temp_ifs=${IFS}
IFS=','
ipArr=(${CliqrTier_siwapp_haproxy_app_PUBLIC_IP}) # Array of IPs in my tier.

# Iterate through list of hosts to add hosts and corresponding IPs to haproxy config file.
host_index=0
for host in $CliqrTier_siwapp_haproxy_app_HOSTNAME ; do
    sudo su -c "echo '${ipArr[${host_index}]} ${host}' >> /etc/hosts"
    let host_index=${host_index}+1
done

# Set internal separator to ',' since they're comma-delimited lists.
temp_ifs=${IFS}
IFS=','
ipArr=(${CliqrTier_siwapp_app_PUBLIC_IP}) # Array of IPs in my tier.

# Iterate through list of hosts to add hosts and corresponding IPs to haproxy config file.
host_index=0
for host in $CliqrTier_siwapp_app_HOSTNAME ; do
    sudo su -c "echo '${ipArr[${host_index}]} ${host}' >> /etc/hosts"
    let host_index=${host_index}+1
done

# Install virtualenv and locustio
virtualenv /usr/share/venv
/usr/share/venv/bin/pip install locustio lxml requests

# Get locust file
sudo curl -o /usr/share/systemd/siwapp-locust-file.py https://raw.githubusercontent.com/vtlevin/cloudcenter/master/siwapp-locust-file.py
# Get locust service file
sudo curl -o /usr/share/systemd/siwapp-locust-service.sh https://raw.githubusercontent.com/vtlevin/cloudcenter/master/siwapp-locust-service.sh

sudo su -c "echo $'
[Unit]
Description=siwapp-simulator

[Service]
Type=simple
User=root
ExecStart=/usr/bin/bash /usr/share/systemd/siwapp-locust-service.sh
Restart=on-abort


[Install]
WantedBy=multi-user.target'\
>> /etc/systemd/system/siwapp-simulator.service
" 
sudo systemctl daemon-reload
sudo systemctl enable siwapp-simulator
sudo systemctl start siwapp-simulator

echo "198.169.195.125 dangerous2019031501233911.saas.appdynamics.com" >> /etc/hosts

agentSendLogMessage "Installing Java"
sudo yum install java-1.8.0-openjdk-headless -y

agentSendLogMessage "Installing Tet Pre-reqs."

sudo yum -y install ipset
sudo yum -y install unzip

agentSendLogMessage "Install Tetration Agent"
# Get Tet Script
#curl https://raw.githubusercontent.com/vtlevin/cloudcenter/master/instant-pov_installer_enforcer_linux.sh | sudo bash
curl https://raw.githubusercontent.com/vtlevin/cloudcenter/master/sales5-tetration_installer_enforcer_linux.sh | sudo bash

sudo mv ~/cliqr.repo /etc/yum.repos.d/
