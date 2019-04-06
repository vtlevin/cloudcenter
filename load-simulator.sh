#!/usr/bin/env bash
exec > >(tee -a /var/tmp/load-simulator-node-init_$$.log) 2>&1

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
    CliqrTier_siwapp_haproxy_app_PUBLIC_IP=$CliqrTier_siwapp_haproxy_app_IP
    cliqrNodePublicIp=$cliqrNodePrivateIp
fi

sudo mv /etc/yum.repos.d/cliqr.repo ~

sudo yum -y update
sudo yum install -y epel-release
sudo yum install -y python-pip
sudo pip install pip --upgrade
sudo pip install requests lxml pyping

sudo curl -o /usr/share/systemd/siwapp-load-generator.py https://raw.githubusercontent.com/vtlevin/cloudcenter/master/siwapp-load-generator-cliqr.py

sudo su -c "echo $'
[Unit]
Description=siwapp-simulator

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python /usr/share/systemd/siwapp-load-generator.py
Restart=on-abort


[Install]
WantedBy=multi-user.target'\
>> /etc/systemd/system/siwapp-simulator.service
" 
sudo systemctl daemon-reload
sudo systemctl enable siwapp-simulator
sudo systemctl start siwapp-simulator

sudo mv ~/cliqr.repo /etc/yum.repos.d/
