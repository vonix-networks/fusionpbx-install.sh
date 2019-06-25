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
