#!/bin/bash
#
# Slaver/conver XIV snapshotting script
# Matvey Marinin 2014
#
# $1 = master volume SCSI WWID
# $2 = snapshot volume SCSI WWID (content will be overwritten)
#
set -e

#XIV DNS name to use
XIV=xiv2

#XCLI path
XCLI=/opt/ibm/xiv/xcli

if [[ -z "$1" || -z "$2" ]]; then
  echo "Usage: $(basename $0) <master volume SCSI WWID> <pre-created snapshot volume SCSI WWID>"
  exit 2
fi

#get XIV volume list with WWIDs
VOLUME_LIST=$("$XCLI" -m "$XIV" vol_list -l -t "name,wwn"|tail -n+2)
#echo "$VOLUME_LIST"

MASTER_VOL=$( echo "$VOLUME_LIST" | awk -v IGNORECASE=1 -v wwid=$1 '$2==substr(wwid,2) {print $1;}' ) #'# fix syntax highlighting
echo "Master volume name=$MASTER_VOL"

SNAPSHOT_VOL=$( echo "$VOLUME_LIST" | awk -v IGNORECASE=1 -v wwid=$2 '$2==substr(wwid,2) {print $1;}' ) #'# fix syntax highlighting
echo "Snapshot volume name=$SNAPSHOT_VOL"

#Overwrite existing snapshot with new one
echo "Creating snapshot"
"$XCLI" -m "$XIV" snapshot_create vol="$MASTER_VOL" overwrite="$SNAPSHOT_VOL"