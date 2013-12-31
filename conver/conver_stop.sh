#!/bin/bash

### Stop PG services
for d in /etc/init.d/postgresql-9.1_*; do echo "Stopping $d"; "$d" stop; done

### unmount helper function
unmount_tree()
{
  local MOUNT_ROOT=$1
  if [[ -n "$MOUNT_ROOT" && "$MOUNT_ROOT" != "/" ]]; then
    for m in $(cat /proc/mounts | awk '$2 ~ "^'"$MOUNT_ROOT"'" {print length($2), $2;}' | sort -nr | awk '{ print $2}'); do echo "Unmounting $m"; umount "$m"; done
  fi
}
###fix mcedit syntax highlighting #'###

## Unmount PG filesystems
for d in /var/lib/pgsql/9.1_*; do echo "Unmounting tree $d:"; unmount_tree "$d"; done

## Deactivate LVM volume groups
for v in $(vgs -o vg_name --noheadings 2>/dev/null | grep 'vg_test'); do echo "Deactivating $v"; vgchange -an "$v"; done
lvs

### Stop PG on test-db-slaver
ssh root@test-db-slaver 'for p in /etc/init.d/postgresql-9.1*; do "$p" stop; done; ps auxf|grep postgres'

### Unmount PG data filesystems on test-db-slaver
ssh root@test-db-slaver 'for d in /var/lib/pgsql/9.1_*; do echo "Unmounting $d/data"; umount "$d/data"; done; mount'