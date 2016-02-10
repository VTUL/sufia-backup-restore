#!/bin/sh

# Restore data backed up for VTechData

BACKUP_ROOT="/home/vagrant/backups"
APP_USER="vagrant"
APP_DIR="/home/vagrant/data-repo"
DB_NAME="datarepo"
DB_USER="vagrant"
DB_PASS="changeme"
DB_HOST="localhost"
DB_PORT="5432"
DB_LOGS="/var/log/postgresql"
SOLR_DATA="/var/solr/data"
SOLR_LOGS="/var/solr/logs"
TOMCAT_LOGS="/var/log/tomcat7"
WEB_LOGS="/var/log/nginx"
RAILS_LOGS="/home/vagrant/data-repo/log"

if [ $# -ge 1 ]; then
  BACKUP_DIR="$1"
fi
if [ $# -ge 2 ]; then
  shift;
  echo -n "Ignoring extra arguments: $@"
fi

# Shut down services to quiesce them
echo "Stopping VTechData services..."
service nginx stop
service solr stop
service tomcat7 stop
service resque-pool stop

echo "VTechData services stopped."

# Set up .pgpass file for pg_dump
PGPASSFILE=$(mktemp)
PGPASS_ENTRY="${DB_HOST}:${DB_PORT}:${DB_NAME}:${DB_USER}:${DB_PASS}"
echo ${PGPASS_ENTRY} > "$PGPASSFILE"
chmod 0600 "$PGPASSFILE"

# Restore SQL database and logs
sudo -i -u postgres dropdb --if-exists $DB_NAME
sudo -i -u postgres dropuser --if-exists $DB_USER
sudo -i -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"
sudo -i -u postgres psql -c "CREATE DATABASE ${DB_NAME} WITH OWNER ${DB_USER} ENCODING 'UTF8';"
sudo -i -u postgres PGPASSFILE="$PGPASSFILE" pg_restore -Fc -d $DB_NAME "${BACKUP_DIR}/pgsqldb.dump"
echo "DB restored from ${BACKUP_DIR}/pgsqldb.dump"
rm "$PGPASSFILE"
tar -x -p -z -f "${BACKUP_DIR}/db_logs.tar.gz" -C "$DB_LOGS" .
echo "DB logs restored from ${BACKUP_DIR}/db_logs.tar.gz"

# Restore Solr core data and logs
tar -x -p -z -f "${BACKUP_DIR}/solr_data.tar.gz" -C "$SOLR_DATA" .
echo "Solr data restored from ${BACKUP_DIR}/solr_data.tar.gz"
tar -x -p -z -f "${BACKUP_DIR}/solr_logs.tar.gz" -C "$SOLR_LOGS" .
echo "Solr logs restored from ${BACKUP_DIR}/solr_logs.tar.gz"

# Restore Fedora data
FEDORA_DATA=$(egrep -o 'fcrepo.home=[^[:space:]]*' /etc/default/tomcat7 | cut -d = -f 2)
tar -x -p -z -f "${BACKUP_DIR}/fedora_data.tar.gz" -C "$FEDORA_DATA" .
echo "Fedora data restored from ${BACKUP_DIR}/fedora_data.tar.gz"

# Restore Tomcat logs
tar -x -p -z -f "${BACKUP_DIR}/tomcat_logs.tar.gz" -C "$TOMCAT_LOGS" .
echo "Tomcat logs restored from ${BACKUP_DIR}/tomcat_logs.tar.gz"

# Restore Web and application logs
tar -x -p -z -f "${BACKUP_DIR}/web_logs.tar.gz" -C "$WEB_LOGS" .
echo "Web logs restored from ${BACKUP_DIR}/web_logs.tar.gz"
tar -x -p -z -f "${BACKUP_DIR}/rails_logs.tar.gz" -C "$RAILS_LOGS" .
echo "Rails logs restored from ${BACKUP_DIR}/rails_logs.tar.gz"

# Clean any caches
cd "$APP_DIR"
sudo -H -u $APP_USER bundle exec rake tmp:clear

# Start up services again
echo "Starting VTechData services..."
service resque-pool start
service tomcat7 start
service solr start
service nginx start

echo "VTechData services started."
