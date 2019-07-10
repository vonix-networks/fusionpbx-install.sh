#!/bin/bash

if [ "$EUID" -ne 0 ]
        then echo "Please run as root"
        exit
fi

# Terminate all services prior to moving configuration
service nginx stop
service fail2ban stop
service php7.2-fpm stop
service memcached stop
service freeswitch stop

# First, move /etc configuration over
mkdir -p /data/etc

mv /etc/fusionpbx /data/etc
ln -s /data/etc/fusionpbx /etc/fusionpbx

mv /etc/freeswitch /data/etc
ln -s /data/etc/freeswitch /etc/freeswitch

mv /etc/fail2ban /data/etc
ln -s /data/etc/fail2ban /etc/fail2ban

mv /etc/nginx /data/etc
ln -s /data/etc/nginx /etc/nginx

mkdir -p /data/var/lib

mv /var/lib/freeswitch /data/var/lib
ln -s /data/var/lib/freeswitch /var/lib/freeswitch

mkdir -p /data/usr/share

mv /usr/share/freeswitch /data/usr/share
ln -s /data/usr/share/freeswitch /usr/share/freeswitch

mkdir -p /data/var/www

mv /var/www/fusionpbx /data/var/www
ln -s /data/var/www/fusionpbx/ /var/www/fusionpbx

