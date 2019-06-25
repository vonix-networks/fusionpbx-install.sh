#!/bin/sh

#move to script directory so all relative paths work
cd "$(dirname "$0")"

#includes
. ../config.sh

#set the date
now=$(date +%Y-%m-%d)

database_password=$PGPASSWORD

#enable odbc-dsn in the xml
sed -i /etc/freeswitch/autoload_configs/db.conf.xml -e s:'<!--<param name="odbc-dsn" value="$${dsn}"/>-->:<param name="odbc-dsn" value="$${dsn}"/>:'
sed -i /etc/freeswitch/autoload_configs/fifo.conf.xml -e s:'<!--<param name="odbc-dsn" value="$${dsn}"/>-->:<param name="odbc-dsn" value="$${dsn}"/>:'
sed -i /etc/freeswitch/autoload_configs/switch.conf.xml -e s:'<!-- <param name="core-db-dsn" value="$${dsn}" /> -->:<param name="core-db-dsn" value="$${dsn}" />:'

#enable odbc-dsn in the sip profiles
sudo -u postgres psql -h $database_host -p $database_port -U freeswitch -d fusionpbx -c "update v_sip_profile_settings set sip_profile_setting_enabled = 'true' where sip_profile_setting_name = 'odbc-dsn';";

#add the dsn variables
sudo -u postgres psql -h $database_host -p $database_port -U freeswitch -d fusionpbx -c "insert into v_vars (var_uuid, var_name, var_value, var_category, var_enabled, var_order, var_description, var_hostname) values ('785d7013-1152-4a44-aa15-28336d9b36f9', 'dsn_system', 'pgsql://hostaddr=$database_host port=$database_port dbname=fusionpbx user=fusionpbx password=$database_password options=', 'DSN', 'true', '0', null, null);";
sudo -u postgres psql -h $database_host -p $database_port -U freeswitch -d fusionpbx -c "insert into v_vars (var_uuid, var_name, var_value, var_category, var_enabled, var_order, var_description, var_hostname) values ('0170e737-b453-40ea-99f2-f1375474e5ce', 'dsn', 'pgsql://hostaddr=$database_host port=$database_port dbname=freeswitch user=fusionpbx password=$database_password options=', 'DSN', 'true', '0', null, null);";
sudo -u postgres psql -h $database_host -p $database_port -U freeswitch -d fusionpbx -c "insert into v_vars (var_uuid, var_name, var_value, var_category, var_enabled, var_order, var_description, var_hostname) values ('32e3e364-a8ef-4fe0-9d02-c652d5122bbf', 'dsn_callcenter', 'sqlite:///var/lib/freeswitch/db/callcenter.db', 'DSN', 'true', '0', null, null);";

#add the 
echo "<!-- DSN -->" >> /etc/freeswitch/vars.xml
echo "<X-PRE-PROCESS cmd=\"set\" data=\"dsn_system=pgsql://hostaddr=$database_host port=$database_port dbname=fusionpbx user=fusionpbx password=$database_password options=\" />" >> /etc/freeswitch/vars.xml
echo "<X-PRE-PROCESS cmd=\"set\" data=\"dsn=pgsql://hostaddr=$database_host port=$database_port dbname=freeswitch user=freeswitch password=$database_password options=\" />" >> /etc/freeswitch/vars.xml
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

#flush memcache
/usr/bin/fs_cli -x 'memcache flush'

#restart freeswitch
service freeswitch restart
