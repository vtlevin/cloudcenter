#!/bin/bash -x
exec > >(tee -a /var/tmp/apache-node-init_$$.log) 2>&1

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

# Set internal separator to ',' since they're comma-delimited lists.
temp_ifs=${IFS}
IFS=','
ipArr=(${CliqrTier_siwapp_haproxy_db_PUBLIC_IP}) # Array of IPs in my tier.

# Iterate through list of hosts to add hosts and corresponding IPs to haproxy config file.
host_index=0
for host in $CliqrTier_siwapp_haproxy_db_HOSTNAME ; do
    sudo su -c "echo '${ipArr[${host_index}]} ${host}' >> /etc/hosts"
    let host_index=${host_index}+1
done
# Set internal separator back to original.
IFS=${temp_ifs}

# agentSendLogMessage $(env)

#---------Script Variables------------#
#siwapp_APP_PORT=$1

#---------DO NOT MODIFY BELOW------------#
sudo mv /etc/yum.repos.d/cliqr.repo ~

agentSendLogMessage "Starting app install script"
sudo yum -y update
#sudo yum -y install git httpd php php-mysql php-xml php-mbstring
sudo yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
sudo yum -y install http://rpms.remirepo.net/enterprise/remi-release-7.rpm
sudo yum -y install yum-utils
sudo yum-config-manager --enable remi-php56
sudo yum -y install git httpd php php-mcrypt php-cli php-gd php-curl php-mysql php-ldap php-zip php-fileinfo php-xml php-mbstring
sudo yum clean all

sudo git clone https://github.com/siwapp/siwapp-sf1.git /var/www/html/

sudo mkdir /var/www/html/cache
sudo chmod 777 /var/www/html/cache
sudo chmod 777 /var/www/html/web/config.php
sudo chmod 777 /var/www/html/config/databases.yml

sudo mkdir /var/www/html/web/uploads
sudo chmod 777 /var/www/html/web/uploads

sudo chown -R apache:apache /var/www/html/

sudo sed -i -e '57,63d' /var/www/html/web/pre_installer_code.php

sudo sed -i "s/80/8443/" /etc/httpd/conf/httpd.conf
sudo sed -i "s/LogFormat \"%h/LogFormat \"%a/g" /etc/httpd/conf/httpd.conf

sudo sed -i "21s%.*%${cliqrNodeHostname}%g" /var/www/html/apps/siwapp/templates/layout.php

sudo su -c "echo $'<Directory /var/www/html/web>
	Options FollowSymLinks
	AllowOverride All
</Directory>
<VirtualHost *:8443>
	DocumentRoot /var/www/html/web
	RewriteEngine On
</VirtualHost>'\
>> /etc/httpd/conf/httpd.conf"

sudo su -c "cat << EOF > /var/www/html/config/databases.yml
all:
  doctrine:
    class: sfDoctrineDatabase
    param:
      dsn: 'mysql:host=${CliqrTier_siwapp_haproxy_db_PUBLIC_IP};dbname=siwapp'
      username: 'siwapp'
      password: '!Ciscodc123'

test:
  doctrine:
    class: sfDoctrineDatabase
    param:
      dsn: 'mysql:host=${CliqrTier_siwapp_haproxy_db_PUBLIC_IP};dbname=siwapp_test'
      #dsn: 'mysql:host=${CliqrTier_siwapp_haproxy_db_IP};dbname=siwapp_test'
      username: 'siwapp'
      password: '!Ciscodc123'
EOF
"

sudo sed -i.bak "s#false#true#g" /var/www/html/web/config.php

agentSendLogMessage "Restarting http services"
sudo systemctl enable httpd
sudo systemctl start httpd
agentSendLogMessage "App install script complete"

sudo mv ~/cliqr.repo /etc/yum.repos.d/
