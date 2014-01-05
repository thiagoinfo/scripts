#!/bin/bash
# 
# Скрипт для настройки нового инстанса FCM для заданного сервера
#
# config_backup.sh <db_server> [<instance_dir>] [<db_port>]
#
# config_backup.sh fcm-test-db
# config_backup.sh test-db-slaver /var/lib/pgsql/9.1_5433
#
# Параметры:
#   <db_server>    - DNS-имя сервера БД
#   <instance_dir> - необязательный параметр для серверов с несколькими инстансами БД, путь вида /var/lib/pgsql/9.1_5433. Если не указан - берется стандартный /var/lib/pgsql/9.1
#   <db_port>      - необязательный параметр для серверов с несколькими инстансами, номер порта Postgres. Если не указан - берется из <instance_dir> или стандартный 5432
#
# Схема chroot:
# /var/run/fcm/<db_name>/<instance>/ = chroot( / )
#                                  |
#                                  -- dev,proc,sys,tmp = mount_bind( соответствующие служебные ФС )
#                                  |
#                                  -- var/lib/pgsql/<instance>/
#                                                              |
#                                                              -- acs  = mount_bind( /var/fcm/<db_name>/<instance>/acs )
#                                                              -- data = flashcopy mount point
# Каталоги с данными:
# /var/run/fcm/<db_name>/<instance> - корневой каталог chroot инстанса FCM
# /var/fcm/<db_name>/<instance>/acs - каталог acs (бинарники, профиль, логи)
# /var/run/fcm/<db_name>/<instance>/var/lib/pgsql/<instance>/data - по этому пути точка монтирования flashcopy будет видна в корневой ФС
# /var/lib/pgsql - каталог с инстансами БД, видимый через chroot, должен быть пустым в корневой ФС
#

DB_SERVER=$1
INSTANCE_DIR=$2
DB_PORT=$3

STORAGE_SYSTEM="dev-svc1"
ACSD_PORT=50001


if [[ -z "$DB_SERVER" ]]; then
  echo "ERROR: <db_server> is not specified                           " 1>&2
  echo "USAGE: config_backup.sh <db_server> <instance_dir>            " 1>&2
  echo "       config_backup.sh fcm-test-db                           " 1>&2
  echo "       config_backup.sh test-db-slaver /var/lib/pgsql/9.1_5433" 1>&2
  exit 1
fi

# use standard "/var/lib/pgsql/9.1" if instance_dir isn`t supplied
if [[ -z "$INSTANCE_DIR" ]]; then
  INSTANCE_DIR="/var/lib/pgsql/9.1"
  INSTANCE="9.1"
else
  #extract instance name from db path
  INSTANCE=$(basename "$INSTANCE_DIR")

  #extract port from instance name
  [[ -z "$DB_PORT" ]] && DB_PORT=$( expr match $INSTANCE '.*\([0-9][0-9][0-9][0-9]\)' ) #'
fi

[[ -z "$DB_PORT" ]] && DB_PORT="5432"

#extract hostname from db_server fqdn
DB_NAME=${DB_SERVER%%.*}

echo "DB_NAME = $DB_NAME"
echo "INSTANCE_DIR = $INSTANCE_DIR"
echo "INSTANCE = $INSTANCE"
echo "DB_PORT = $DB_PORT"

# шаблон чистого каталога acs с исполняемыми файлами
ACS_TEMPLATE="/opt/tivoli/acs_template"

######################################################################
# setuputil
# function check_ssh_key_auth <remote host> <username on remote host>
# check if we could login without a password login
######################################################################
check_ssh_key_auth()
{
server="$1"
username="$2"
echo "Checking SSH key authentication..."
ssh -q -o "BatchMode=yes" ${username}@${server} "echo 2>&1"
if test $? -eq 0; then
  echo "SSH key authentication was successful."
  return 0;
else
  echo "SSH key authentication failed.";
  return 2;
fi
}

######################################################################
# выводит в stdout глобальную часть профиля
# Parameters:
# $1 = ACS_DIR
# $2 = ACDS_SERVER
# $3 = ACSD_PORT
######################################################################
profile_global()
{
cat <<EOF
>>> GLOBAL
ACS_DIR $1
ACSD $2 $3
TRACE YES
<<<

EOF
}


######################################################################
# выводит в stdout профиль конфигурации ACSD
# Parameters:
# $1 = ACS_DIR
######################################################################
profile_acsd()
{
cat <<EOF
>>> ACSD
ACS_REPOSITORY $1/repo
# REPOSITORY_LABEL TSM
<<<

EOF
}

######################################################################
# выводит в stdout клиентский профиль PS
# Parameters:
# $1 = ACS_DIR
# $2 = INSTANCE_DIR
# $3 = DB_PORT
######################################################################
profile_client_PS()
{
cat <<EOF
>>> CLIENT
# BACKUPIDPREFIX GEN___
APPLICATION_TYPE GENERIC
INFILE $1/infile
PRE_FLASH_CMD $1/pgsql-preflash-cmd -p $3 -d "$2/data "
POST_FLASH_CMD $1/pgsql-postflash-cmd -p $3 -d "$2/data "
TSM_BACKUP LATEST
MAX_VERSIONS ADAPTIVE
# LVM_FREEZE_THAW AUTO
NEGATIVE_LIST NO_CHECK
TIMEOUT_FLASH 120
# GLOBAL_SYSTEM_IDENTIFIER
DEVICE_CLASS STANDARD
TIMEOUT_PARTITION 180
TIMEOUT_PREPARE 180
TIMEOUT_VERIFY 1200
TIMEOUT_CLOSE 1200
<<<

EOF
}

######################################################################
# Выводит в stdout ограниченный клиентский профиль BS
# Нужен для работы команды inquire на BS
######################################################################
profile_client_BS()
{
cat <<EOF
>>> CLIENT
# BACKUPIDPREFIX GEN___
APPLICATION_TYPE GENERIC
TSM_BACKUP LATEST
MAX_VERSIONS ADAPTIVE
NEGATIVE_LIST NO_CHECK
<<<

EOF
}

######################################################################
# выводит в stdout профиль offload
# Parameters:
# $1 = DB_NAME
######################################################################
profile_offload()
{
cat <<EOF
>>> OFFLOAD
BACKUP_METHOD TSM_CLIENT
# MODE FULL
ASNODENAME $DB_NAME_FCM
DSM_DIR /opt/tivoli/tsm/client/ba/bin
# DSM_CONFIG
# VIRTUALFSNAME fcm
<<<

EOF
}

######## настройка удаленного сервера БД (BS) #########################
echo "##### Configuring database server $DB_SERVER #####"

# настраиваем рутовый ssh-доступ без пароля к серверу БД
# необходим для настройки FCM и последующего запуска бакапов
if ! check_ssh_key_auth $DB_SERVER "root"; then
  echo "Configuring SSH key authentication..."
  { ssh-copy-id "root@$DB_SERVER" && check_ssh_key_auth $DB_SERVER "root"; } || { echo "Could not enable SSH key authentication" 1>&2; exit 1; }
fi

# останавливаем демоны acsd и acsgend
DB_ACSD="acsd"
DB_ACSGEND="acsgend"
if [[ "$INSTANCE" != "9.1"  ]]; then
  DB_ACSD="$DB_ACSD-$INSTANCE"
  DB_ACSGEND="$DB_ACSGEND-$INSTANCE"
fi

echo "Stopping $DB_ACSD and $DB_ACSGEND"
ssh "root@$DB_SERVER" "if initctl status $DB_ACSGEND | grep -qcF start; then initctl stop $DB_ACSGEND; fi";
ssh "root@$DB_SERVER" "if initctl status $DB_ACSD    | grep -qcF start; then initctl stop $DB_ACSD;    fi";

DB_ACS_DIR="$INSTANCE_DIR/acs"

# копируем исполняемые файлы FCM
echo "Copying FCM binary"
rsync -a --exclude '/logs/' --exclude '/pipes/' --exclude '/repo/' --exclude '/shared/' --exclude '/profile*' --exclude '/infile*' --exclude '/fcmcert.*' --exclude '/fcmselfcert.arm' "$ACS_TEMPLATE/" "root@$DB_SERVER:$DB_ACS_DIR/"

# создаем файлы конфигурации:
echo "Writing config files"

# создаем файл конфигурации sudo для запуска fsfreeze из-под postgres
ssh "root@$DB_SERVER" "cat > /etc/sudoers.d/06_fcm" <<EOF
Defaults:postgres !requiretty
postgres ALL=NOPASSWD:/sbin/fsfreeze
EOF

# записываем infile
ssh "root@$DB_SERVER" "echo $INSTANCE_DIR/data/PG_VERSION > $DB_ACS_DIR/infile"

# записываем profile
profile_global    "$DB_ACS_DIR" "$DB_SERVER" "$ACSD_PORT"  | ssh "root@$DB_SERVER" "cat > $DB_ACS_DIR/profile"
profile_acsd      "$DB_ACS_DIR"                            | ssh "root@$DB_SERVER" "cat >> $DB_ACS_DIR/profile"
profile_client_PS "$DB_ACS_DIR" "$INSTANCE_DIR" "$DB_PORT" | ssh "root@$DB_SERVER" "cat >> $DB_ACS_DIR/profile"

# добавляем в profile конфигурацию заданной системы хранения
STORAGE_SYSTEM_TEMPLATE="$ACS_TEMPLATE/profile.$STORAGE_SYSTEM"

if [[ -f "$STORAGE_SYSTEM_TEMPLATE" ]]; then
  echo "Configuring storage system profile for $STORAGE_SYSTEM"
  ssh "root@$DB_SERVER" "cat >> $DB_ACS_DIR/profile" < "$STORAGE_SYSTEM_TEMPLATE"
  # также копируем файл паролей для заданной системы хранения
  rsync -a "$ACS_TEMPLATE/shared/pwd.acsd.$STORAGE_SYSTEM" "root@$DB_SERVER:$DB_ACS_DIR/shared/pwd.acsd"
else
  echo "Cant find storage system profile: $STORAGE_SYSTEM_TEMPLATE" 1>&2
  exit 1
fi

# настраиваем сертификаты на сервере БД (PS): удаляем существующую базу сертификатов и генерируем новые с помощью утилиты FCM setup_gen.sh
ssh "root@$DB_SERVER" "rm -f $DB_ACS_DIR/fcmcert.* $DB_ACS_DIR/fcmselfcert.arm"
ssh "root@$DB_SERVER" "$DB_ACS_DIR/setup_gen.sh -a enable_gskit_PS -d $DB_ACS_DIR/.."

# исправляем владельца файлов: везде postgres:postgres, у двух suid-binary acsd и fcmutil владелец root:postgres
echo "Fixing file ownership"
ssh "root@$DB_SERVER" "chown -R postgres:postgres $DB_ACS_DIR"
ssh "root@$DB_SERVER" "chown root:postgres $DB_ACS_DIR/acsd $DB_ACS_DIR/fcmutil"

# настройка BS закончена, запускаем демоны acsd и acsgend
echo "Starting $DB_ACSD and $DB_ACSGEND"
ssh "root@$DB_SERVER" "if initctl status $DB_ACSD    | grep -qcF stop; then initctl start $DB_ACSD;    fi";
ssh "root@$DB_SERVER" "if initctl status $DB_ACSGEND | grep -qcF stop; then initctl start $DB_ACSGEND; fi";

###### настройка локального сервера (BS) ####################################
echo "##### Configuring backup server #####"

# корень chroot
CHROOT_DIR="/var/run/fcm/$DB_NAME/$INSTANCE"

# каталог нового инстанса FCM
ACS_DIR="/var/fcm/$DB_NAME/$INSTANCE/acs"

# путь к каталогу FCM внутри chroot
CHROOT_ACS_DIR="$INSTANCE_DIR/acs"

# имя инстанса mount-демона
ACSGENMNT="acsgenmntd_$DB_NAME"

# имя upstart-файла mount-демона
ACSGENMNT_CONF="/etc/init/$ACSGENMNT.conf"

# останавливаем mount daemon
if [[ -f "$ACSGENMNT_CONF" ]]; then
  echo "Stage 1: Stopping FCM mount daemon: $ACSGENMNT"
  initctl stop "$ACSGENMNT"
fi

# настраиваем новый инстанс FCM
if [[ ! -e "$ACS_DIR" ]]; then
  mkdir -p "$ACS_DIR"
  chown postgres:postgres "$ACS_DIR"
fi

echo "Stage 2: Deploying FCM binaries to $ACS_DIR"
# обновляем бинарные файлы FCM из шаблона
# в каталоге шаблона не должно быть рабочих подкаталогов shared,logs и файлов profile, infile, сертификатов
rsync -aW --exclude '/logs/' --exclude '/pipes/' --exclude '/repo/' --exclude '/shared/' --exclude '/profile*' --exclude '/infile' --exclude '/fcmcert.*' --exclude '/fcmselfcert.arm' "$ACS_TEMPLATE/" "$ACS_DIR/"

echo "Stage 3: Copying FCM configuration from server $DB_SERVER ($INSTANCE_DIR/acs)"
# копируем конфигурационные файлы FCM с сервера БД
rsync -a "root@$DB_SERVER:$INSTANCE_DIR/acs/fcmselfcert.arm" ":$INSTANCE_DIR/acs/shared/pwd.acsd" ":$INSTANCE_DIR/acs/infile" "$ACS_DIR/"

# записываем профиль BS
profile_global "$CHROOT_ACS_DIR" "$DB_SERVER" "$ACSD_PORT" | cat > "$ACS_DIR/profile"
profile_client_BS                                          | cat >> "$ACS_DIR/profile"
profile_offload "$DB_NAME"                                 | cat >> "$ACS_DIR/profile"

# настраиваем сертификаты на бакапере (BS): удаляем существующую базу сертификатов и экспортируем сертификат fcmselfcert.arm с помощью утилиты FCM setup_gen.sh
rm -f "$ACS_DIR/fcmcert.crl" "$ACS_DIR/fcmcert.kdb" "$ACS_DIR/fcmcert.rdb" "$ACS_DIR/fcmcert.sth"
"$ACS_DIR/setup_gen.sh" -a enable_gskit_BS -d "$ACS_DIR/.."

# исправляем владельца файлов: везде postgres:postgres, у двух suid-binary acsd и fcmutil владелец root:postgres
echo "Fixing file ownership"
chown -R postgres:postgres "$ACS_DIR"
chown root:postgres "$ACS_DIR/acsd" "$ACS_DIR/fcmutil"

echo "Stage 4: Configuring FCM mount daemon $ACSGENMNT"
# настраиваем upstart-файл mount-демона
[[ -f "$ACSGENMNT_CONF" ]] && rm -f "$ACSGENMNT_CONF"

cat >"$ACSGENMNT_CONF" <<EOF
description     "FlashCopy Manager Mount Service"
author          "IBM Corp."

start on stopped rc RUNLEVEL=[2345]
stop on starting rc RUNLEVEL=[016]

chroot $CHROOT_DIR

console output
respawn

pre-start script
  [ -x "$CHROOT_ACS_DIR/acsgen" ] || { stop; exit 0; }
end script

script
  "$CHROOT_ACS_DIR/acsgen" -D -M -s STANDARD
end script
EOF

######################################################################
# Filter out specified mount point from /etc/fstab
# Parameters:
# $1 = mount target
function filter_fstab()
{
  awk '/^#/ || $2!="'$1'" {print $0}' /etc/fstab > /etc/fstab.new
  mv -f /etc/fstab.new /etc/fstab
}

######################################################################
# Append bind-mount to /etc/fstab
# Parameters:
# $1 = source mount
# $2 = bind target
function append_fstab()
{
  echo "$1		$2		none bind" >> /etc/fstab
}

### настройка chroot ###
echo "Stage 5: Configuring chroot $CHROOT_DIR"

TARGET_ACS_DIR="${CHROOT_DIR}${INSTANCE_DIR}/acs"
TARGET_DATA_DIR="${CHROOT_DIR}${INSTANCE_DIR}/data"

# backup fstab
cat /etc/fstab > /etc/fstab.bak

# required chroot mounts
CHROOT_MOUNTS="$CHROOT_DIR $CHROOT_DIR/dev $CHROOT_DIR/dev/pts $CHROOT_DIR/dev/shm $CHROOT_DIR/proc $CHROOT_DIR/sys $CHROOT_DIR/tmp $TARGET_ACS_DIR"

# check /etc/fstab for all mounts to exist
FSTAB_OK=1
for m in $CHROOT_MOUNTS; do
  if ! awk '!/^#/ {print $2;}' /etc/fstab | grep -cxqF "$m"; then
    FSTAB_OK=0
  fi
done

if (( "FSTAB_OK"== 0 )); then
  #one of required mounts does not exists in /etc/fstab
  echo "Configuring /etc/fstab"

  #remove existing bind-mounts
  for m in $CHROOT_MOUNTS; do filter_fstab "$m"; done
  
  #prepend empty line if need
  if [[ -n "$(tail -n1 /etc/fstab)" ]]; then echo >> /etc/fstab; fi

  #add all required bind-mounts in a right order
  append_fstab /		$CHROOT_DIR
  append_fstab /dev		$CHROOT_DIR/dev
  append_fstab /dev/pts		$CHROOT_DIR/dev/pts
  append_fstab /dev/shm		$CHROOT_DIR/dev/shm
  append_fstab /proc		$CHROOT_DIR/proc
  append_fstab /sys		$CHROOT_DIR/sys
  append_fstab /tmp		$CHROOT_DIR/tmp
  append_fstab $ACS_DIR		$TARGET_ACS_DIR
fi

######################################################################
# Mount /etc/fstab entry if need
# Parameters:
# $1 = mount target
function mnt_helper {
  MOUNT_POINT=${1%/} #remove trailing slash
  if ! awk '{ print $2}' /proc/mounts | grep -cxqF "$MOUNT_POINT"; then
    echo "Mounting $MOUNT_POINT"
    mount "$MOUNT_POINT"
  fi
}

mnt_helper $CHROOT_DIR
mnt_helper $CHROOT_DIR/dev
mnt_helper $CHROOT_DIR/dev/pts
mnt_helper $CHROOT_DIR/dev/shm
mnt_helper $CHROOT_DIR/proc
mnt_helper $CHROOT_DIR/sys
mnt_helper $CHROOT_DIR/tmp
mnt_helper $TARGET_ACS_DIR
mkdir -pv "$TARGET_DATA_DIR"

# show chroot mounts
#mount | awk '$3~"^'$CHROOT_DIR'" {print}'

# start mount daemon
echo "Stage 6: Starting FCM mount daemon: $ACSGENMNT"
initctl start "$ACSGENMNT"
