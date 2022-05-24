#!/bin/bash

VER=0
echo "What version do you want to install?"
echo "1) 4.0 LTS"
echo "2) 5.0 LTS"

read -p "Please, select number 1 or 2 : " yn

case "$yn" in
    1) echo "Do you want to install 4.0 LTS?";
     VER=1;
     ;;
    2) echo "Do you want to install 5.0 LTS?";
     VER=2;
     ;;
   *) echo "Abort the installation.";
     exit ;;
esac
read -p "Hit enter: "
echo "VER="$VER

if [ "$VER" == "1" ];then
    rpm -Uvh https://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-release-4.0-2.el7.noarch.rpm
elif [ "$VER" == "2" ];then
    rpm -Uvh https://repo.zabbix.com/zabbix/5.0/rhel/7/x86_64/zabbix-release-5.0-1.el7.noarch.rpm
    yum update -y
    
else
    echo "Abort the installation."
    exit;
fi

if type setenforce >/dev/null 2>&1; then
    RET=`getenforce`
    if [ "${RET}" != "Disabled" ];then
        setenforce 0
    fi
fi

systemctl stop firewalld
systemctl disable firewalld

if [ -e "/etc/selinux/config" ];then
    sed -i -e "s/SELINUX=enforcing/SELINUX=disabled/" /etc/selinux/config
fi


yum clean all

if [ "$VER" == "1" ];then
    yum install -y zabbix-server-mysql zabbix-web-mysql zabbix-agent
    echo date.timezone = `timedatectl | grep "Time zone" | awk '{print $3}'` >> /etc/php.ini
elif [ "$VER" == "2" ];then
    yum install -y centos-release-scl
    yum install -y zabbix-server-mysql zabbix-agent
    sed -i -z 's/enabled=0/enabled=1/1' < /etc/yum.repos.d/zabbix.repo /etc/yum.repos.d/zabbix.repo
    yum install -y zabbix-web-mysql-scl zabbix-apache-conf-scl
    echo php_value[date.timezone] = `timedatectl | grep "Time zone" | awk '{print $3}'` >> /etc/opt/rh/rh-php72/php-fpm.d/zabbix.conf
fi

yum install -y mariadb-server.x86_64
systemctl start mariadb
systemctl enable mariadb


DB=mysql
PASSWORD="1234"

SQL=`cat << EOS
use $DB
create database zabbix character set utf8 collate utf8_bin;
grant all privileges on zabbix.* to zabbix@localhost identified by '${PASSWORD}';

EOS`
echo "$SQL" | mysql -u root

zcat `find  /usr/share/doc/zabbix-server-mysql* |  grep create.sql.gz` | mysql -uzabbix -p${PASSWORD} zabbix

sed -i -e "s/# DBPassword=/DBPassword=${PASSWORD}/" /etc/zabbix/zabbix_server.conf

TEXT="
<?php \n\
// Zabbix GUI configuration file. \n\
global \$DB; \n\
\n\
\$DB['TYPE']     = 'MYSQL'; \n\
\$DB['SERVER']   = 'localhost'; \n\
\$DB['PORT']     = '0'; \n\
\$DB['DATABASE'] = 'zabbix'; \n\
\$DB['USER']     = 'zabbix'; \n\
\$DB['PASSWORD'] = '${PASSWORD}'; \n\
 \n\
// Schema name. Used for PostgreSQL. \n\
\$DB['SCHEMA'] = ''; \n\
 \n\
\$ZBX_SERVER      = 'localhost'; \n\
\$ZBX_SERVER_PORT = '10051'; \n\
\$ZBX_SERVER_NAME = 'test'; \n\
\n\
\$IMAGE_FORMAT_DEFAULT = IMAGE_FORMAT_PNG; "
echo -e $TEXT > /etc/zabbix/web/zabbix.conf.php
chmod 644 /etc/zabbix/web/zabbix.conf.php

if [ "$VER" == "1" ];then
    systemctl restart zabbix-server zabbix-agent httpd
    systemctl enable zabbix-server zabbix-agent httpd
elif [ "$VER" == "2" ];then
    systemctl restart zabbix-server httpd rh-php72-php-fpm
    systemctl enable zabbix-server httpd rh-php72-php-fpm
    echo "Please, reboot now."
fi

echo "Zabbix Install Completed."

yum -y install wget


systemctl start zabbix-agent
systemctl enable zabbix-agent

mysql -u zabbix -p1234
use zabbix;
update zabbix.users set passwd=md5('1234') where alias='Admin';

9
#wget https://dl.grafana.com/enterprise/release/grafana-enterprise-7.2.2-1.x86_64.rpm
#yum -y install grafana-enterprise-7.2.2-1.x86_64.rpm
#grafana-cli plugins install alexanderzobnin-zabbix-app 3.12.4
##grafana-cli plugins install grafana-image-renderer
##yum install -y  alsa-lib.x86_64 atk.x86_64 cups-libs.x86_64 gtk3.x86_64 ipa-gothic-fonts libXcomposite.x86_64 libXcursor.x86_64 libXdamage.x86_64 libXext.x86_64 libXi.x86_64 libXrandr.x86_64 libXScrnSaver.x86_64 libXtst.x86_64 pango.x86_64 xorg-x11-fonts-100dpi xorg-x11-fonts-75dpi xorg-x11-fonts-cyrillic xorg-x11-fonts-misc xorg-x11-fonts-Type1 xorg-x11-utils
##yum update nss -y
##service grafana-server restart
