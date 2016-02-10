#!/bin/sh

# Back up important data for VTechData

BACKUP_ROOT="/home/vagrant/backups"
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

# Shut down services to quiesce them
echo "Stopping VTechData services..."
service nginx stop
service solr stop
service tomcat7 stop
service resque-pool stop

echo "VTechData services stopped."

# Make backup subdir
BACKUP_DIR="${BACKUP_ROOT}/backup.$(date +%Y-%m-%d-%H%M%S)"
if [ -e "${BACKUP_DIR}" ]; then
  echo "Error: ${BACKUP_DIR} exists; not overwriting."
  exit 1
else
  mkdir -p "${BACKUP_DIR}"
fi

echo "Backup directory $BACKUP_DIR created."

# Set up .pgpass file for pg_dump
PGPASSFILE=$(mktemp)
PGPASS_ENTRY="${DB_HOST}:${DB_PORT}:${DB_NAME}:${DB_USER}:${DB_PASS}"
echo ${PGPASS_ENTRY} > "$PGPASSFILE"
chmod 0600 "$PGPASSFILE"

# Dump SQL database and logs
env PGPASSFILE="$PGPASSFILE" pg_dump -Fc -f "${BACKUP_DIR}/pgsqldb.dump" -U $DB_USER -h $DB_HOST -p $DB_PORT $DB_NAME
echo "DB dumped to ${BACKUP_DIR}/pgsqldb.dump"
rm "$PGPASSFILE"
tar -c -z -f "${BACKUP_DIR}/db_logs.tar.gz" -C "$DB_LOGS" .
echo "DB logs dumped to ${BACKUP_DIR}/db_logs.tar.gz"

# Copy Solr core data and logs
tar -c -z -f "${BACKUP_DIR}/solr_data.tar.gz" -C "$SOLR_DATA" .
echo "Solr data dumped to ${BACKUP_DIR}/solr_data.tar.gz"
tar -c -z -f "${BACKUP_DIR}/solr_logs.tar.gz" -C "$SOLR_LOGS" .
echo "Solr logs dumped to ${BACKUP_DIR}/solr_logs.tar.gz"

# Copy Fedora data
FEDORA_DATA=$(egrep -o 'fcrepo.home=[^[:space:]]*' /etc/default/tomcat7 | cut -d = -f 2)
tar -c -z -f "${BACKUP_DIR}/fedora_data.tar.gz" -C "$FEDORA_DATA" .
echo "Fedora data dumped to ${BACKUP_DIR}/fedora_data.tar.gz"

# Copy Tomcat logs
tar -c -z -f "${BACKUP_DIR}/tomcat_logs.tar.gz" -C "$TOMCAT_LOGS" .
echo "Tomcat logs dumped to ${BACKUP_DIR}/tomcat_logs.tar.gz"

# Copy Web and application logs
tar -c -z -f "${BACKUP_DIR}/web_logs.tar.gz" -C "$WEB_LOGS" .
echo "Web logs dumped to ${BACKUP_DIR}/web_logs.tar.gz"
tar -c -z -f "${BACKUP_DIR}/rails_logs.tar.gz" -C "$RAILS_LOGS" .
echo "Rails logs dumped to ${BACKUP_DIR}/rails_logs.tar.gz"

# Start up services again
echo "Starting VTechData services..."
service resque-pool start
service tomcat7 start
service solr start
service nginx start

echo "VTechData services started."
