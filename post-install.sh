#!/bin/bash

if [ "$EUID" -ne 0 ]
        then echo "Please run as root"
        exit
fi

# We need to use the configuration set in config.sh to move data from
# the local PostgreSQL instance to Cloud SQL
. ./post-config.sh

if [ -z $FUSIONPBX_DB_HOST ]; then
	echo "Please edit and fill in configuration information in config.sh"
	exit 1
fi

# First, move /etc configuration over
mkdir -p /data/etc

mv /etc/fusionpbx /data/etc
ln -s /data/etc/fusionpbx /etc/fusionpbx

mv freeswitch /data/etc
ln -s /data/etc/freeswitch /etc/freeswitch

mv /etc/fail2ban /data/etc
ln -s /data/etc/fail2ban /etc/fail2ban

mkdir -p /data/var/lib

mv /var/lib/freeswitch /data/var/lib
ln -s /data/var/lib/freeswitch /var/lib/freeswitch

mkdir -p /data/usr/share

mv /usr/share/freeswitch /data/usr/share
ln -s /data/usr/share/freeswitch /usr/share/freeswitch

mkdir -p /data/var/www

mv /var/www/fusionpbx /data/var/www
ln -s /data/var/www/fusionpbx/ /var/www/fusionpbx

# Configure /etc/fusionpbx/config.lua
cp /etc/fusionpbx/config.lua /etc/fusionpbx/config.lua.orig
sed -i 's/database.system = .*/database.system = "pgsql://hostaddr=${FUSIONPBX_DB_HOST} port=${FUSIONPBX_DB_PORT} dbname=${FUSIONPBX_DB_NAME} user=${FUSIONPBX_DB_USER} password=${FUSIONPBX_DB_PASS} options=''";/' /etc/fusionpbx/config.lua
sed -i 's/database.switch = .*/database.switch = "pgsql://hostaddr=${FREESWITCH_DB_HOST} port=${FREESWITCH_DB_PORT} dbname=${FREESWITCH_DB_NAME} user=${FREESWITCH_DB_USER} password=${FREESWITCH_DB_PASS} options=''";/' /etc/fusionpbx/config.lua

# Export old configuration
OLD_FUSION_DB_HOST="$(grep db_host /etc/fusionpbx/config.php | cut -d "'" -f 2)"
OLD_FUSION_DB_PORT="$(grep db_port /etc/fusionpbx/config.php | cut -d "'" -f 2)"
OLD_FUSION_DB_NAME="$(grep db_name /etc/fusionpbx/config.php | cut -d "'" -f 2)"
OLD_FUSION_DB_USER="$(grep db_username /etc/fusionpbx/config.php | cut -d "'" -f 2)"
OLD_FUSION_DB_PASS="$(grep db_password /etc/fusionpbx/config.php | cut -d "'" -f 2)"

# Configure /etc/fusionpbx/config.php
cp /etc/fusionpbx/config.php /etc/fusionpbx/config.php.orig
sed "s/db_host = .*/db_host = '${FUSIONPBX_DB_HOST}';/" /etc/fusionpbx/config.php
sed "s/db_port = .*/db_port = '${FUSIONPBX_DB_PORT}';/" /etc/fusionpbx/config.php
sed "s/db_name = .*/db_name = '${FUSIONPBX_DB_NAME}';/" /etc/fusionpbx/config.php
sed "s/db_username = .*/db_username = '${FUSIONPBX_DB_USER}';/" /etc/fusionpbx/config.php
sed "s/db_password = .*/db_password = '${FUSIONPBX_DB_PASS}';/" /etc/fusionpbx/config.php

# Migrate data to new location
export PGPASSWORD=${OLD_FUSION_DB_PASS}
pg_dump -U ${OLD_FUSION_DB_USER} -h ${OLD_FUSION_DB_HOST} -p ${OLD_FUSION_DB_PORT} -f /tmp/fusionpbx_dump.sql ${OLD_FUSION_DB_NAME}

export PGPASSWORD=${FUSIONPBX_DB_PASS}
FUSIONPBX_PSQL="psql -U ${FUSIONPBX_DB_USER} -h ${FUSIONPBX_DB_HOST} -p ${FUSIONPBS_DB_PORT} -d ${FUSIONPBX_DB_NAME}"
FREESWITCH_PSQL="psql -h ${FREESWITCH_DB_HOST} -p ${FREESWITCH_DB_PORT} -U ${FREESWITCH_DB_USER} -d ${FREESWITCH_DB_NAME}"

${FUSIONPBX_PSQL} < /tmp/fusionpbx_dump.sql

export PGPASSWORD=${FREESWITCH_DB_PASS}
${FREESWITCH_PSQL} -c "create extension pgcrypto;";
${FREESWITCH_PSQL} -f /var/www/fusionpbx/resources/install/sql/switch.sql -L /tmp/schema.log;

#enable odbc-dsn in the xml
sed -i /etc/freeswitch/autoload_configs/db.conf.xml -e s:'<!--<param name="odbc-dsn" value="$${dsn}"/>-->:<param name="odbc-dsn" value="$${dsn}"/>:'
sed -i /etc/freeswitch/autoload_configs/fifo.conf.xml -e s:'<!--<param name="odbc-dsn" value="$${dsn}"/>-->:<param name="odbc-dsn" value="$${dsn}"/>:'
sed -i /etc/freeswitch/autoload_configs/switch.conf.xml -e s:'<!-- <param name="core-db-dsn" value="$${dsn}" /> -->:<param name="core-db-dsn" value="$${dsn}" />:'

#enable odbc-dsn in the sip profiles
export PGPASSWORD=${FUSIONPBX_DB_PASS}
${FUSIONPBX_PSQL} -c "update v_sip_profile_settings set sip_profile_setting_enabled = 'true' where sip_profile_setting_name = 'odbc-dsn';";

#add the dsn variables
${FUSIONPBX_PSQL} -c "insert into v_vars (var_uuid, var_name, var_value, var_category, var_enabled, var_order, var_description, var_hostname) values ('785d7013-1152-4a44-aa15-28336d9b36f9', 'dsn_system', 'pgsql://hostaddr=${FUSIONPBX_DB_HOST} port=${FUSIONPBX_DB_PORT} dbname=${FUSIONPBX_DB_NAME} user=${FUSIONPBX_DB_USER} password=${FUSIONPBX_DB_PASS} options=', 'DSN', 'true', '0', null, null);";
${FUSIONPBX_PSQL} -c "insert into v_vars (var_uuid, var_name, var_value, var_category, var_enabled, var_order, var_description, var_hostname) values ('0170e737-b453-40ea-99f2-f1375474e5ce', 'dsn', 'pgsql://hostaddr=${FREESWITCH_DB_HOST} port=${FREESWITCH_DB_PORT} dbname=${FREESWITCH_DB_NAME} user=${FREESWITCH_DB_USER} password=${FREESWITCH_DB_PASS} options=', 'DSN', 'true', '0', null, null);";
${FUSIONPBX_PSQL} -c "insert into v_vars (var_uuid, var_name, var_value, var_category, var_enabled, var_order, var_description, var_hostname) values ('32e3e364-a8ef-4fe0-9d02-c652d5122bbf', 'dsn_callcenter', 'sqlite:///var/lib/freeswitch/db/callcenter.db', 'DSN', 'true', '0', null, null);";

#add the dsn to vars.xml
echo "<!-- DSN -->" >> /etc/freeswitch/vars.xml
echo "<X-PRE-PROCESS cmd=\"set\" data=\"dsn_system=pgsql://hostaddr=${FUSIONPBX_DB_HOST} port=${FUSIONPBX_DB_PORT} dbname=${FUSIONPBX_DB_NAME} user=${FUSIONPBX_DB_USER} password=${FUSIONPBX_DB_PASS} options=\" />" >> /etc/freeswitch/vars.xml
echo "<X-PRE-PROCESS cmd=\"set\" data=\"dsn=pgsql://hostaddr=${FREESWITCH_DB_HOST} port=${FREESWITCH_DB_PORT} dbname=${FREESWITCH_DB_NAME} user=${FREESWITCH_DB_USER} password=${FREESWITCH_DB_PASS} options=\" />" >> /etc/freeswitch/vars.xml
echo "<X-PRE-PROCESS cmd=\"set\" data=\"dsn_callcenter=sqlite:///var/lib/freeswitch/db/callcenter.db\" />" >> /etc/freeswitch/vars.xml

#remove the sqlite database files
dbs="/var/lib/freeswitch/db/core.db /var/lib/freeswitch/db/fifo.db /var/lib/freeswitch/db/call_limit.db /var/lib/freeswitch/db/sofia_reg_*"
for db in ${dbs};
do
  if [ -f $db ]; then
    echo "Deleting $db";
    rm $db
  fi
done
