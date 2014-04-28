#!/bin/bash

set -e

if [[ -z "$1" ]]; then
  echo "ERROR: required parameter is not specified!"
  echo "Usage: conver_instance_prepare.sh 5433"
  exit 2
fi


INSTANCE=$1
INSTANCE_DIR=/var/lib/pgsql/9.1_$1
echo "Instance dir: $INSTANCE_DIR"
if [[ ! -d "$INSTANCE_DIR" ]]; then
  echo "ERROR: directory $INSTANCE_DIR does not exist"
  exit 1
fi

PG_SERVICE=postgresql-9.1_$INSTANCE
echo "Postgresql instance name: $PG_SERVICE"

echo "### Unfreezing $INSTANCE_DIR/data on test-db-slaver ###"
### Unfreeze PG_data filesystem on test-db-slaver
ssh root@test-db-slaver "fsfreeze -u $INSTANCE_DIR/data"

### Start PG on test-db-slaver
echo "### Starting $PG_SERVICE on test-db-slaver ###"
ssh root@test-db-slaver "service $PG_SERVICE start" || true

echo
echo "### Mounting filesystems on test-db-conver ###"
echo
## Activate LVM volume groups
echo "- - -" | tee /sys/class/scsi_host/host*/scan > /dev/null
pvscan
for v in $(vgs -o vg_name --noheadings 2>/dev/null | grep 'vg_test'); do echo "Activating $v"; vgchange -ay "$v"; done

### mount helper
mount_tree()
{
  local MOUNT_ROOT=$1
  if [[ -n "$MOUNT_ROOT" && "$MOUNT_ROOT" != "/" ]]; then
    for m in $(cat /proc/mounts | awk '$2 ~ "^'"$MOUNT_ROOT"'" {print length($2), $2;}' | sort -n | awk '{ print $2}'); do echo "Mounting $m"; mount "$m"; done
    ###fix mcedit syntax highlighting #'###
  fi
}

## Mount PG filesystems and create trigger file
echo "Mounting $INSTANCE_DIR/data"
mount "$INSTANCE_DIR/data"

echo "Mounting $INSTANCE_DIR/data/pg_stat_tmp"
mount "$INSTANCE_DIR/data/pg_stat_tmp";

touch "$INSTANCE_DIR/data/trigger"
chown postgres:postgres "$INSTANCE_DIR/data/trigger"

### Start PG services
echo "Starting $PG_SERVICE on test-db-conver"
service "$PG_SERVICE" start

