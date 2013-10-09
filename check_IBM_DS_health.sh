#!/bin/bash
#
#########################################################
#
# IBM DSxx health monitoring
# 
# Usage:  check_IBM_health.sh <DS_controller>
# Output: empty line if status is OK
#         comma-separated failure descriptions if where is errors
#
# Matvey Marinin 2013
#
# Based on http://exchange.nagios.org/directory/Plugins/Hardware/Storage-Systems/SAN-and-NAS/check_IBM_DS_health/details
#
#########################################################
#
#   Check state of IBM DS4x00/5x00 Health Status
#   
#   uses IBM SMclient package, tested with version 10.70 & 10.83 
#
#   created by Martin Moebius
#
#   05.10.2011 - 1.0 * initial version
#
#   28.11.2011 - 1.1 * added Status "Warning" instead of "Critical" in case of Preferred Path error
#                    * changed filtering of SMcli output to string based sed instead of position based awk
#                    * moved filtering of SMcli output to remove redundant code
#                    * more comments on code
#
#   06.02.2012 - 1.2 * added patch from user "cseres", better SMcli output parsing
#
#   03.09.2012 - 1.3 * filter controller clock sync warning from output
#
#   13.11.2012 - 1.4 * changed result parsing to fix "Unreadable sector" messages from DS3300/3400 not getting reported correctly
#
#   08.01.2012 - 1.5 * changed result parsing to fix "Battery Expiration" messages not getting reported correctly
#                    * added another wildcard entry in the nested "case"-statement to get at least a UNKNOWN response for any possible message
#
#########################################################

#SMcli location
COMMAND=/opt/IBM_DS/client/SMcli

#
# Check the health status via SMcli
#

##execute SMcli
RESULT=$($COMMAND $1 -c "show storageSubsystem healthStatus;")

############ Sample command output ###########
#
# Warning! No Monitor password is set for the storage subsystem.
# Performing syntax check...
# 
# Syntax check complete.
# 
# Executing script...
# 
# Storage Subsystem health status = fixing.
# The following failures have been found:
# Logical Drive - Hot Spare In Use
# Storage Subsystem: ea1-ds4
# Array: RAID_5_EXP2
#   Status: Degraded
#   RAID level: 5
#   Failed drive at: enclosure 1, slot 4
#     Service action (removal) allowed: Yes
#     Service action LED on component: Yes
#   Replaced by drive at: enclosure 2, slot 24
#   Logical Drives: ea1-ds4-VStorage4, ea1-db1_BACKUP-R1, ea1-ds4-VStorage5, ea1-ds4-VStorage8, ea1-ds4-email-arch1_DATA, ea1-osr-adm-db1-backup, ea1-ds4-VStorage6, ea1-osr-u2-db1-backup
# 
# Degraded Logical Drive
# Storage Subsystem: ea1-ds4
#   Array: RAID_5_EXP2
#     RAID level: 5
#     Status: Degraded
#       Enclosure: Drive expansion enclosure 1
#         Affected drive slot(s): 4
#           Service action (removal) allowed: Yes
#           Service action LED on component: Yes
#     Logical Drives: ea1-ds4-VStorage8, ea1-osr-adm-db1-backup, ea1-ds4-VStorage6, ea1-osr-u2-db1-backup
# 
# Script execution complete.
# 
# SMcli completed successfully.
# 

###DEBUG
#echo "$RESULT"


# Find lines beginning with "Storage Subsystem:", the lines above it is a failure descriptions, grub it to single output message
#
#
echo "$RESULT" | grep -E -B1 '^Storage Subsystem:' | grep -vE '^Storage Subsystem:|^--' | sed ':a;N;$!ba;s/\n/, /g' | sed 's/ $//g'
