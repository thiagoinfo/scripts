#!/bin/bash
#
# Unmount filesystems mounted at $1 root
#
# Usage: cleanup_mounts.sh /var/lib/pgsql/9.1/osr-XXX
#
MOUNT_ROOT=$1
if [[ -n "$MOUNT_ROOT" && "$MOUNT_ROOT" != "/" ]]; then
  for m in $(cat /proc/mounts | awk '$2 ~ "^'"$MOUNT_ROOT"'" {print length($2), $2;}' | sort -nr | awk '{ print $2}'); do echo "unmounting $m"; umount "$m"; done
else
  echo "Usage: cleanup_mounts.sh <mount_root>" 1>&2
  echo "<mount_root> can not be empty or \"/\"" 1>&2
  exit 1
fi


