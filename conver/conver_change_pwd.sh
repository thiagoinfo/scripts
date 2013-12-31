#!/bin/bash

pushd /var/lib/pgsql 1>/dev/null
for p in /var/lib/pgsql/9.1_*; do
  PGPORT=$(expr match $p '.*\([0-9][0-9][0-9][0-9]\)'); #'
  echo "Connecting to $PGPORT"
  sudo -u postgres psql -p $PGPORT -c "alter user postgres with password 'postgres';"
done
popd 1>/dev/null