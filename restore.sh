#!/bin/sh

# Restore data backed up for VTechData

APP_USER="vagrant"
APP_DIR="/home/vagrant/data-repo"
DB_NAME="datarepo"
DB_USER="vagrant"
DB_PASS="changeme"
DB_HOST="localhost"
DB_PORT="5432"
DB_IS_REMOTE="NO"
DB_ADMIN_USER="postgres"
DB_ADMIN_DB="postgres"
DB_ADMIN_PASSWORD="MyAdminPW"
DB_LOGS="/var/log/postgresql"
SOLR_DATA="/var/solr/data"
SOLR_LOGS="/var/solr/logs"
TOMCAT_LOGS="/var/log/tomcat7"
WEB_LOGS="/var/log/nginx"
RAILS_LOGS="/home/vagrant/data-repo/log"
REDIS_DIR=$(redis-cli config get dir|tail -1)
REDIS_DB=$(redis-cli config get dbfilename|tail -1)

if [ $# -ge 1 ]; then
  BACKUP_DIR="$1"
fi
if [ $# -ge 2 ]; then
  shift;
  echo -n "Ignoring extra arguments: $@"
fi

# Validate DB_IS_REMOTE
case $DB_IS_REMOTE in
  [Yy][Ee][Ss])
    DB_IS_REMOTE="YES"
    echo "Assuming DB is on remote server."
    ;;
  *)
    DB_IS_REMOTE="NO"
    echo "Assuming DB is local."
    ;;
esac

# Shut down services to quiesce them
echo "Stopping VTechData services..."
service nginx stop
service solr stop
service tomcat7 stop
service resque-pool stop

echo "VTechData services stopped."

# Restore SQL database and logs
if [ "$DB_IS_REMOTE" = "YES" ]; then
  # Set up .pgpass file for remote commands
  PGPASSFILE=$(mktemp)
  echo "${DB_HOST}:${DB_PORT}:${DB_NAME}:${DB_ADMIN_USER}:${DB_ADMIN_PASSWORD}" > "$PGPASSFILE"
  echo "${DB_HOST}:${DB_PORT}:${DB_ADMIN_DB}:${DB_ADMIN_USER}:${DB_ADMIN_PASSWORD}" >> "$PGPASSFILE"
  chmod 0600 "$PGPASSFILE"
  export PGHOST=$DB_HOST
  export PGPORT=$DB_PORT
  export PGUSER=$DB_ADMIN_USER
  export PGDATABASE=$DB_ADMIN_DB
  export PGPASSFILE
  psql -c "DROP DATABASE IF EXISTS ${DB_NAME};"
  psql -c "DROP USER IF EXISTS ${DB_USER};"
  psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"
  pg_restore -C -d $DB_ADMIN_DB "${BACKUP_DIR}/pgsqldb.dump"
  rm "$PGPASSFILE"
else
  sudo -u postgres dropdb --if-exists -e $DB_NAME
  sudo -u postgres dropuser --if-exists -e $DB_USER
  sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"
  sudo -u postgres pg_restore -C -d postgres "${BACKUP_DIR}/pgsqldb.dump"
fi
echo "DB restored from ${BACKUP_DIR}/pgsqldb.dump"
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

# Restore Redis queue
service redis-server stop
tar -x -p -z -f "${BACKUP_DIR}/redis_queue.tar.gz" -C "$REDIS_DIR"
echo "Redis queue restored from ${BACKUP_DIR}/redis_queue.tar.gz"
service redis-server restart

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
