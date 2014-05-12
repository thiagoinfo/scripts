#!/bin/bash
#
# test-db-slaver/test-db-conver snapshotting script
# Copies specified PostgreSQL database from test-db-slaver to test-db-conver using XIV snapshot
#
# Matvey Marinin 2014
#
# Usage: conver_snapshot_instance.sh <port>
#
# Requirements:
#   XIV xcli (~/xivGUI-4.3.1-build1-linux64.bin) for XIV snapshot functionality
#   JRE (~/jre-7u55-linux-x64.rpm) for xcli installation
#
#   12.05.2014: Uses remote script xcli@admin-tools:/usr/local/bin/slaver-xiv-snapshot.sh to make XIV snapshots

set -e

if [[ -z "$1" ]]; then
  echo "ERROR: required parameter is not specified!"
  echo "Usage: conver_instance_prepare.sh 5433"
  exit 2
fi

INSTANCE=$1
DATA_DIR=/var/lib/pgsql/9.1_$1/data
echo "Data dir: $DATA_DIR"
if [[ ! -d "$DATA_DIR" ]]; then
  echo "ERROR: directory $DATA_DIR does not exist"
  exit 1
fi

PG_SERVICE=postgresql-9.1_$INSTANCE
echo "Postgresql instance name: $PG_SERVICE"

### Stop PG service on test-db-conver
echo "Stopping $PG_SERVICE on test-db-conver"
service "$PG_SERVICE" stop || true

### Check if instance filesystem is mounted ###
if [[ -n "$(awk '$2 ~ "^'"$DATA_DIR"'$"' /proc/mounts)" ]]; then

  ## If instance filesystem is mounted, find volume group to deactivate in /proc/mounts
  VG_NAME=$(awk '$1 ~ "/dev/mapper/" && $2 ~ "'$DATA_DIR'" {print gensub("^/dev/mapper/(.+)-(.+)", "\\1", "g", $1);}' /proc/mounts)
  ###Comment to fix MCedit syntax highlighting ' " ###

  ### unmount helper function
  unmount_tree()
  {
    local MOUNT_ROOT=$1
    if [[ -n "$MOUNT_ROOT" && "$MOUNT_ROOT" != "/" ]]; then
      for m in $(cat /proc/mounts | awk '$2 ~ "^'"$MOUNT_ROOT"'" {print length($2), $2;}' | sort -nr | awk '{ print $2}'); do
        ###fix mcedit syntax highlighting #'###
        echo "Unmounting $m"
        #Kill processes preventing filesystem umounting
        fuser -mvk "$m" || true
        #Unmount filesystem
        umount "$m"
      done
    fi
  }

  ## Unmount PG filesystem tree
  echo "Unmounting tree $DATA_DIR:"
  unmount_tree "$DATA_DIR"

## If instance filesystem is not mounted, try to find volume group to deactivate in /etc/fstab
elif [[ -n "$(awk '$2 ~ "^'"$DATA_DIR"'$"' /etc/fstab)" ]]; then
  VG_NAME=$(awk '$1 ~ "/dev/mapper/" && $2 ~ "'$DATA_DIR'" {print gensub("^/dev/mapper/(.+)-(.+)", "\\1", "g", $1);}' /etc/fstab)
  ###Comment to fix MCedit syntax highlighting ' " ###
else
  echo "WARNING: Could not find $DATA_DIR mountpoint"
fi

SCSI_ID_SNAPSHOT=$(scsi_id --whitelisted --device=$(pvs -o vg_name,pv_name --noheadings 2>/dev/null | awk '$1=="vg_test_9999" {print $2}')) #"#
echo "SCSI_ID_SNAPSHOT=$SCSI_ID_SNAPSHOT"

SCSI_ID_MASTER=$( ssh root@test-db-slaver "scsi_id --whitelisted --device=\$(pvs -o vg_name,pv_name --noheadings 2>/dev/null | awk -v vg=vg_test_9999 '\$1==vg {print \$2}')" ) #"#
echo "SCSI_ID_MASTER=$SCSI_ID_MASTER"

[[ -n "$SCSI_ID_SNAPSHOT" ]] || (echo "Could not get snapshot volume SCSI WWID"; exit 1;)
[[ -n "$SCSI_ID_MASTER" ]] || (echo "Could not get master volume SCSI WWID"; exit 1;)

## Deactivate LVM volume groups
if [[ -z "$VG_NAME" ]]; then
  echo "ERROR: Could not found volume group to deactivate"
  exit 1
fi

echo "Deactivating VG $VG_NAME on test-db-conver"
vgchange -an "$VG_NAME" >/dev/null 2>&1

### Stop PG on test-db-slaver ###
echo "Stopping PostgreSQL on test-db-slaver"
ssh root@test-db-slaver "service $PG_SERVICE stop" || true

### Freeze PGDATA filesystem on test-db-slaver ###
echo "Freezing filesystem $DATA_DIR on test-db-slaver"
ssh root@test-db-slaver "fsfreeze -f $DATA_DIR"


### Call remote script on admin-tools to make volume snapshot ###
ssh xcli@admin-tools /usr/local/bin/slaver-xiv-snapshot.sh "$SCSI_ID_MASTER" "$SCSI_ID_SNAPSHOT"


### Unfreeze PGDATA filesystem on test-db-slaver
echo "Unfreezing $DATA_DIR on test-db-slaver ###"
ssh root@test-db-slaver "fsfreeze -u $DATA_DIR"

### Start PG on test-db-slaver
echo "Starting PostgreSQL on test-db-slaver ###"
ssh root@test-db-slaver "service $PG_SERVICE start" || true

echo "Preparing PostgreSQL on test-db-conver..."
## Activate LVM volume groups
echo "Activating volume groups"
echo "- - -" | tee /sys/class/scsi_host/host*/scan > /dev/null
pvscan >/dev/null 2>&1
for v in $(vgs -o vg_name --noheadings 2>/dev/null | grep 'vg_test'); do vgchange -ay "$v" >/dev/null 2>&1; done

### mount helper
mount_tree()
{
  local MOUNT_ROOT=$1
  if [[ -n "$MOUNT_ROOT" && "$MOUNT_ROOT" != "/" ]]; then
    for m in $(cat /proc/mounts | awk '$2 ~ "^'"$MOUNT_ROOT"'" {print length($2), $2;}' | sort -n | awk '{ print $2}'); do
      ##fix mcedit syntax highlighting #'#
      echo "Mounting $m"
      mount "$m"
    done
  fi
}

## Mount PG filesystems
echo "Mounting $DATA_DIR"
mount "$DATA_DIR"

echo "Mounting $DATA_DIR/pg_stat_tmp"
mount "$DATA_DIR/pg_stat_tmp";

echo "Creating PG trigger file"
touch "$DATA_DIR/trigger"
chown postgres:postgres "$DATA_DIR/trigger"

### Start PG services
echo "Starting PostgreSQL on test-db-conver"
service "$PG_SERVICE" start

### Wait for database startup and reset "postgres" password
while :
do
  echo "Waiting for PostgreSQL startup..."
  sleep 10
  echo "Trying to reset \"postgres\" user password"
  if (sudo -u postgres psql -p $1 -c "alter user postgres with password 'postgres';") then
    break
  fi
done


