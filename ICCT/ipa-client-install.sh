#!/bin/bash
#
# IPA Client installation script
#
# 2013 Matvey Marinin
#
# Usage:
#   export IPA_SKIP_INSTALL={YES|NO}
#   ipa-client-install.sh
#
# Parameters are passed as environment variables:
#   IPA_SKIP_INSTALL={YES|NO} - skip IPA client installation/upgrade (package ipa-client must be already installed)
#

set -e

if [[ $IPA_SKIP_INSTALL != "YES" ]] ; then
  yum -y install ipa-client
fi