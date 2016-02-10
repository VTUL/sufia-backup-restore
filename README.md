Scripts to Back Up and Restore Data Repository Application
==========================================================

These two scripts can be used to back up and restore the Sufia [data repository application](https://github.com/VTUL/data-repo).  The `backup.sh` script is used to back up and `restore.sh` to restore.

Both scripts need to have settings configured to define various attributes about the installed Sufia application.  This is done (for now) by editing the block of settings near the beginning of each script.  The `restore.sh` script takes one argument: the pathname to the directory containing the backup to restore.  This should be an absolute pathname.

When backing up and restoring the scripts will stop and start the application as necessary, to ensure the files backed up and restored are consistent.
