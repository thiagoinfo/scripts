#!/bin/bash
#
# IPA client activation script
#
# 2013 Matvey Marinin
#

set -e

usage()
{
cat >&2 << EOF
 Usage:
   export IPA_USER=...
   export IPA_PWD=...
   $0

 Parameters are passed as environment variables:
   IPA_USER =  authorized kerberos principal to use to join the IPA realm (ipa-client-install -p)
   IPA_PWD  =  password for joining a machine to the IPA realm (ipa-client-install -w)
EOF
}

if [[ -z $IPA_USER ]] || [[ -z $IPA_PWD ]] ; then
   echo "ERROR: parameters is missing" >&2
   usage
   exit 1
fi

ipa-client-install --enable-dns-updates --mkhomedir --hostname=$(hostname -f) -p"$IPA_USER" -w"$IPA_PWD" --unattended
