#!/bin/bash
#
# IPA client reset script
#
# 2013 Matvey Marinin
#

set -e

ipa-client-install --uninstall --unattended
