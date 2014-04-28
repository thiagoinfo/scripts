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

### Stop PG services
echo "Stopping $PG_SERVICE"
service "$PG_SERVICE" stop || true

### Check if filesystem is mounted ###
if [[ -n "$(awk '$2 ~ "^/var/lib/pgsql/9.1_5435/data$"' /proc/mounts)" ]]; then
  ## Unmount filesystem and deactivate volume group
  CONVER_INSTANCE_VG_NAME=$(awk '$1 ~ "/dev/mapper/" && $2 ~ "'$INSTANCE_DIR'" {print gensub("^/dev/mapper/(.+)-(.+)", "\\1", "g", $1);}' /proc/mounts)
  ###Comment to fix MCedit syntax highliting ' " ###

  echo "Volume group to deactivate: $CONVER_INSTANCE_VG_NAME"
  if [[ -z "$CONVER_INSTANCE_VG_NAME" ]]; then
    echo "ERROR: Could not found volume group to deactivate"
    exit 1
  fi

  ### unmount helper function
  unmount_tree()
  {
    local MOUNT_ROOT=$1
    if [[ -n "$MOUNT_ROOT" && "$MOUNT_ROOT" != "/" ]]; then
      for m in $(cat /proc/mounts | awk '$2 ~ "^'"$MOUNT_ROOT"'" {print length($2), $2;}' | sort -nr | awk '{ print $2}'); do echo "Unmounting $m"; umount "$m"; done
      ###fix mcedit syntax highlighting #'###
    fi
  }

  ## Unmount PG filesystems
  echo "Unmounting tree $INSTANCE_DIR:"
  unmount_tree "$INSTANCE_DIR"

  ## Deactivate LVM volume groups
  echo "Deactivating $CONVER_INSTANCE_VG_NAME"
  vgchange -an "$CONVER_INSTANCE_VG_NAME"
fi

### Stop PG on test-db-slaver
echo "Stopping Postgresql on test-db-slaver"
ssh root@test-db-slaver "service $PG_SERVICE stop" || true

### Freeze PG data filesystem on test-db-slaver
echo "Freezing filesystem $INSTANCE_DIR/data on test-db-slaver"
ssh root@test-db-slaver "fsfreeze -f $INSTANCE_DIR/data"