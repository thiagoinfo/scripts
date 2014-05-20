#!/bin/bash
#
# Creates snapshot of specified XIV volume
#
# Matvey Marinin 2014
#
# $1 = XIV name (xiv1, xiv2)
# $2 = volume name
# $3 = (optional) existing snapshot to overwrite
#
set -e

#XCLI path
XCLI=/opt/ibm/xiv/xcli

function usage {
  echo "Usage: $(basename $0) <XIV name> <master volume SCSI WWID> [<pre-created snapshot volume SCSI WWID>]"
  exit 2
}

if [[ -z "$1" || -z "$2" ]]; then
  usage
fi

XIV=$1
MASTER_WWID=$(echo "$2" | awk '{if (length($0)>16) print substr($0,2); else print $0;}') #'#
SNAPSHOT_WWID=$(echo "$3" | awk '{if (length($0)>16) print substr($0,2); else print $0;}') #'#

## Get XIV volume list with WWIDs
echo "Getting XIV volume list"
VOLUME_LIST=$("$XCLI" -m "$XIV" vol_list -l -t "name,wwn"|tail -n+2)
#echo "$VOLUME_LIST"

MASTER_VOL=$( echo "$VOLUME_LIST" | awk -v IGNORECASE=1 -v wwid="$MASTER_WWID" '$2==wwid {print $1;}' ) #'# fix syntax highlighting
[[ -n "$MASTER_VOL" ]] || (echo "Could not find volume with WWID=$MASTER_WWID"; exit 1;)
#echo "Master volume name=$MASTER_VOL"

## Check if existing snapshot is specified in a command line
if [[ -n "$SNAPSHOT_WWID" ]]; then
  ## Overwrite existing snapshot
  SNAPSHOT_VOL=$( echo "$VOLUME_LIST" | awk -v IGNORECASE=1 -v wwid="$SNAPSHOT_WWID" '$2==wwid {print $1;}' ) #'# fix syntax highlighting
  [[ -n "$SNAPSHOT_VOL" ]] || (echo "Could not find volume with WWID=$SNAPSHOT_WWID"; exit 1;)
  #echo "Snapshot volume name=$SNAPSHOT_VOL"

  echo "Overwriting snapshot $SNAPSHOT_VOL of volume $MASTER_VOL"
  "$XCLI" -m "$XIV" snapshot_create vol="$MASTER_VOL" overwrite="$SNAPSHOT_VOL"
else
  ## Create new snapshot
  echo "Creating new snapshot of volume $MASTER_VOL"
  "$XCLI" -m "$XIV" snapshot_create vol="$MASTER_VOL"
fi





