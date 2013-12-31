#!/bin/bash

echo "### Starting Postgres on test-db-slaver ###"
### Mount PG data filesystems on test-db-slaver
ssh root@test-db-slaver 'for d in /var/lib/pgsql/9.1_*; do echo "Mounting $d/data on test-db-slaver"; mount "$d/data"; done; mount'

### Start PG on test-db-slaver
ssh root@test-db-slaver 'for p in /etc/init.d/postgresql-9.1_*; do echo "Starting $p on test-db-slaver"; "$p" start; done;'

echo
echo "### Mounting filesystems on test-db-conver ###"
echo
## Activate LVM volume groups
echo "- - -" | tee /sys/class/scsi_host/host*/scan > /dev/null
pvscan
for v in $(vgs -o vg_name --noheadings 2>/dev/null | grep 'vg_test'); do echo "Activating $v"; vgchange -ay "$v"; done
lvs

### mount helper
mount_tree()
{
  local MOUNT_ROOT=$1
  if [[ -n "$MOUNT_ROOT" && "$MOUNT_ROOT" != "/" ]]; then
    for m in $(cat /proc/mounts | awk '$2 ~ "^'"$MOUNT_ROOT"'" {print length($2), $2;}' | sort -n | awk '{ print $2}'); do echo "Mounting $m"; mount "$m"; done
  fi
}
###fix mcedit syntax highlighting #'###

## Mount PG filesystems and create trigger file
for d in /var/lib/pgsql/9.1_*; do 
  echo "Mounting $d/data"; mount "$d/data";
  echo "Mounting $d/data/pg_stat_tmp"; mount "$d/data/pg_stat_tmp";
  
  touch "$d/data/trigger"
  chown postgres:postgres "$d/data/trigger"
done

### Start PG services
for d in /etc/init.d/postgresql-9.1_*; do
 echo "Starting $d on test-db-conver" 
 "$d" start
done
