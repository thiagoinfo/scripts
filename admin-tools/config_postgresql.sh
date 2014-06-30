#!/bin/bash
#
# $1 = server name
# $2 = operation, one of {disable_archiving, enable_archiving, umount_backup, mount_backup, check_archive_command}
#

#echo "$0 $1 $2 $3 $4 $5"
#exit 1

SERVER="$1"
OPER="$2"
USER=$(whoami)


## disable archive_command
if [[ "$OPER" == 'disable_archiving' ]]; then
  ssh -n "$USER@$SERVER" 'sudo sed -i "/^[[:space:]]*#/!s/archive_command.*/archive_command = '"'""'"'/g" /var/lib/pgsql/9.1/data/postgresql.conf; sudo service postgresql-9.1 reload'
fi


## enable archive_command
if [[ "$OPER" == 'enable_archiving' ]]; then
  ssh -n "$USER@$SERVER" 'sudo sed -i "/^[[:space:]]*#/!s/archive_command.*/archive_command='"'"'\/var\/lib\/pgsql\/pitr-back-xlog 5432 %p %f'"'"'/g" /var/lib/pgsql/9.1/data/postgresql.conf; sudo service postgresql-9.1 reload'
fi


## unmount /var/backup
if [[ "$OPER" == 'umount_backup' ]]; then
  ssh -n "$USER@$SERVER" "sudo fuser -mv /var/backup; sudo umount /var/backup"
fi


## mount /var/backup
if [[ "$OPER" == 'mount_backup' ]]; then
  ssh -n "$USER@$SERVER" "sudo mount /var/backup"
fi

## check archive_command
if [[ "$OPER" == 'check_archive_command' ]]; then
  ssh -n "$USER@$SERVER" "sudo -u postgres psql -c 'SHOW archive_command;' -At 2>/dev/null"
fi




