Scripts to Back Up and Restore Data Repository Application
==========================================================

These two scripts can be used to back up and restore the Sufia [data repository application](https://github.com/VTUL/data-repo).  The `backup.sh` script is used to back up and `restore.sh` to restore.

Both scripts need to have settings configured to define various attributes about the installed Sufia application.  This is done (for now) by editing the block of settings near the beginning of each script.  The `restore.sh` script takes one argument: the pathname to the directory containing the backup to restore.  The `backup.sh` can take an optional argument: the pathname to the directory under which backups are stored.  The actual backup will be placed inside a newly-created directory (of the form `backup.YYYY-MM-DD-HHMMSS`) inside the one specified.

When backing up and restoring, the scripts will stop and start the application as necessary, to ensure the files backed up and restored are consistent.

The `restore.sh` script can restore DB data to a remote PostgreSQL server.  If this is intended, the setting `DB_IS_REMOTE="YES"` should be set and the following admin-related DB settings should be provided:

- `DB_ADMIN_USER`: a PostgreSQL user on the remote server that has the ability to create new users and databases;
- `DB_ADMIN_PASSWORD`: the PostgreSQL password of the `DB_ADMIN_USER` user;
- `DB_ADMIN_DB`: a database other than the one to be restored (i.e., other than `DB_NAME`) that the `DB_ADMIN_USER` can connect to whilst performing the restoration of `DB_NAME`.

If PostgreSQL is running locally, set `DB_IS_REMOTE="NO"`.  This will connect to the server via the local PostgreSQL super user, `postgres`.
