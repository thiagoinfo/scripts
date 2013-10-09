lang en_US.UTF-8
keyboard us
timezone --utc Europe/Moscow
auth --useshadow --enablemd5
selinux --disabled
firewall --disabled

bootloader --append="nodiskmount nolvmmount" --timeout=15

#repo --name="a-base" --baseurl=http://vault.centos.org/6.3/os/$basearch/
#repo --name="a-updates" --baseurl=http://vault.centos.org/6.3/updates/$basearch/

repo --name="a-base" --baseurl=http://mirror.centos.org/centos/6/os/$basearch/
repo --name="a-updates" --baseurl=http://mirror.centos.org/centos/6/updates/$basearch/

#repo --name="a-extras" --baseurl=http://mirror.centos.org/centos/6.3/extras/$basearch/
#repo --name="a-centosplus" --baseurl=http://mirror.centos.org/centos/6.3/centosplus/$basearch/
#repo --name="a-contrib" --baseurl=http://mirror.centos.org/centos/6.3/contrib/$basearch/
#repo --name="a-epel" --baseurl=http://download.fedoraproject.org/pub/epel/6/i386


#xconfig --startxonboot
skipx

part / --size 4096 --fstype ext4
services --enabled=NetworkManager --disabled=network,sshd

%packages
syslinux
kernel


@core
@base
 #package added to @base
  squashfs-tools
 #packages removed from @base
 -bind-utils
 -ed
 -kexec-tools
 -libaio
 -libhugetlbfs
 -microcode_ctl
 -psacct
 -quota
 -fprintd-pam
 -irqbalance

#@basic-desktop
 #package removed from @basic-desktop
# -gok

#@desktop-platform
 #packages removed from @desktop-platform
# -redhat-lsb
#@dial-up
#@fonts
#@general-desktop
 #package removed from @general-desktop
# -gnome-backgrounds
# -gnome-user-share
# -nautilus-sendto
# -orca
# -rhythmbox
# -vino
#@graphical-admin-tools
#@input-methods
#@network-file-system-client
#@network-tools
 #package added to @network-tools
# nmap
#@remote-desktop-clients
 #packages added to @remote-desktop-clients
# rdesktop
# tsclient
#@x11

# other usefull packages
busybox
memtest86+
#livecd-tools
module-init-tools

# livecd bits to set up the livecd and be able to install
#anaconda
#device-mapper-multipath
isomd5sum


### my packages  ###
system-config-firewall-base
mc
-hunspell

%end

%post

## default LiveCD user
LIVECD_USER="centos"

########################################################################
# Create a sub-script so the output can be captured
# Must change "$" to "\$" and "`" to "\`" to avoid shell quoting
########################################################################
cat > /root/post-install << EOF_post
#!/bin/bash

echo ###################################################################
echo ## Creating the livesys init script
echo ###################################################################

cat > /etc/rc.d/init.d/livesys << EOF_initscript
#!/bin/bash
#
# live: Init script for live image
#
# chkconfig: 345 00 99
# description: Init script for live image.

. /etc/init.d/functions

if ! strstr "\\\`cat /proc/cmdline\\\`" liveimg || [ "\\\$1" != "start" ]; then
    exit 0
fi

if [ -e /.liveimg-configured ] ; then
    configdone=1
fi


exists() {
    which \\\$1 >/dev/null 2>&1 || return
    \\\$*
}

touch /.liveimg-configured

# mount live image
if [ -b \\\`readlink -f /dev/live\\\` ]; then
   mkdir -p /mnt/live
   mount -o ro /dev/live /mnt/live 2>/dev/null || mount /dev/live /mnt/live
fi

livedir="LiveOS"
for arg in \\\`cat /proc/cmdline\\\` ; do
  if [ "\\\${arg##live_dir=}" != "\\\${arg}" ]; then
    livedir=\\\${arg##live_dir=}
    return
  fi
done

# enable swaps unless requested otherwise
swaps=\\\`blkid -t TYPE=swap -o device\\\`
if ! strstr "\\\`cat /proc/cmdline\\\`" noswap && [ -n "\\\$swaps" ] ; then
  for s in \\\$swaps ; do
    action "Enabling swap partition \\\$s" swapon \\\$s
  done
fi
if ! strstr "\\\`cat /proc/cmdline\\\`" noswap && [ -f /mnt/live/\\\${livedir}/swap.img ] ; then
  action "Enabling swap file" swapon /mnt/live/\\\${livedir}/swap.img
fi

mountPersistentHome() {
  # support label/uuid
  if [ "\\\${homedev##LABEL=}" != "\\\${homedev}" -o "\\\${homedev##UUID=}" != "\\\${homedev}" ]; then
    homedev=\\\`/sbin/blkid -o device -t "\\\$homedev"\\\`
  fi

  # if we're given a file rather than a blockdev, loopback it
  if [ "\\\${homedev##mtd}" != "\\\${homedev}" ]; then
    # mtd devs don't have a block device but get magic-mounted with -t jffs2
    mountopts="-t jffs2"
  elif [ ! -b "\\\$homedev" ]; then
    loopdev=\\\`losetup -f\\\`
    if [ "\\\${homedev##/mnt/live}" != "\\\${homedev}" ]; then
      action "Remounting live store r/w" mount -o remount,rw /mnt/live
    fi
    losetup \\\$loopdev \\\$homedev
    homedev=\\\$loopdev
  fi

  # if it's encrypted, we need to unlock it
  if [ "\\\$(/sbin/blkid -s TYPE -o value \\\$homedev 2>/dev/null)" = "crypto_LUKS" ]; then
    echo
    echo "Setting up encrypted /home device"
    plymouth ask-for-password --command="cryptsetup luksOpen \\\$homedev EncHome"
    homedev=/dev/mapper/EncHome
  fi

  # and finally do the mount
  mount \\\$mountopts \\\$homedev /home
  # if we have /home under what's passed for persistent home, then
  # we should make that the real /home.  useful for mtd device on olpc
  if [ -d /home/home ]; then mount --bind /home/home /home ; fi
  [ -x /sbin/restorecon ] && /sbin/restorecon /home
  if [ -d /home/\\\$LIVECD_USER ]; then USERADDARGS="-M" ; fi
}

findPersistentHome() {
  for arg in \\\`cat /proc/cmdline\\\` ; do
    if [ "\\\${arg##persistenthome=}" != "\\\${arg}" ]; then
      homedev=\\\${arg##persistenthome=}
      return
    fi
  done
}

if strstr "\\\`cat /proc/cmdline\\\`" persistenthome= ; then
  findPersistentHome
elif [ -e /mnt/live/\\\${livedir}/home.img ]; then
  homedev=/mnt/live/\\\${livedir}/home.img
fi

# if we have a persistent /home, then we want to go ahead and mount it
if ! strstr "\\\`cat /proc/cmdline\\\`" nopersistenthome && [ -n "\\\$homedev" ] ; then
  action "Mounting persistent /home" mountPersistentHome
fi

# make it so that we don't do writing to the overlay for things which
# are just tmpdirs/caches
mount -t tmpfs -o mode=0755 varcacheyum /var/cache/yum
mount -t tmpfs tmp /tmp
mount -t tmpfs vartmp /var/tmp
[ -x /sbin/restorecon ] && /sbin/restorecon /var/cache/yum /tmp /var/tmp >/dev/null 2>&1

if [ -n "\\\$configdone" ]; then
  exit 0
fi


## fix various bugs and issues
# unmute sound card
exists alsaunmute 0 2> /dev/null

# turn off firstboot for livecd boots
echo "RUN_FIRSTBOOT=NO" > /etc/sysconfig/firstboot

# turn off mdmonitor by default
chkconfig --level 345 mdmonitor       off 2>/dev/null

# turn off setroubleshoot on the live image to preserve resources
chkconfig --level 345 setroubleshoot  off 2>/dev/null

# don't start cron/at as they tend to spawn things which are
# disk intensive that are painful on a live image
chkconfig --level 345 auditd          off 2>/dev/null
chkconfig --level 345 crond           off 2>/dev/null
chkconfig --level 345 atd             off 2>/dev/null
chkconfig --level 345 readahead_early off 2>/dev/null
chkconfig --level 345 readahead_later off 2>/dev/null

# disable kdump service
chkconfig --level 345 kdump           off 2>/dev/null

# disable microcode_ctl service
chkconfig --level 345 microcode_ctl   off 2>/dev/null

# disable smart card services
chkconfig --level 345 openct          off 2>/dev/null
chkconfig --level 345 pcscd           off 2>/dev/null

# disable postfix service
chkconfig --level 345 postfix         off 2>/dev/null

# Stopgap fix for RH #217966; should be fixed in HAL instead
touch /media/.hal-mtab

# workaround clock syncing on shutdown that we don't want (#297421)
sed -i -e 's/hwclock/no-such-hwclock/g' /etc/rc.d/init.d/halt

# set the LiveCD hostname
sed -i -e 's/HOSTNAME=localhost.localdomain/HOSTNAME=livecd.localdomain/g' /etc/sysconfig/network
/bin/hostname livecd.localdomain

## create the LiveCD default user
# add default user with no password
/usr/sbin/useradd -c "LiveCD default user" $LIVECD_USER
/usr/bin/passwd -d $LIVECD_USER > /dev/null
# give default user sudo privileges
echo "$LIVECD_USER     ALL=(ALL)     NOPASSWD: ALL" >> /etc/sudoers

## configure default user's desktop
# set up timed auto-login at 10 seconds
cat >> /etc/gdm/custom.conf << FOE
[daemon]
TimedLoginEnable=true
TimedLogin=$LIVECD_USER
TimedLoginDelay=10
FOE

# add keyboard and display configuration utilities to the desktop
mkdir -p /home/$LIVECD_USER/Desktop >/dev/null
cp /usr/share/applications/gnome-keyboard.desktop           /home/$LIVECD_USER/Desktop/
cp /usr/share/applications/gnome-display-properties.desktop /home/$LIVECD_USER/Desktop/

# disable screensaver locking
gconftool-2 --direct --config-source=xml:readwrite:/etc/gconf/gconf.xml.defaults -s -t bool   /apps/gnome-screensaver/lock_enabled "false" >/dev/null

# disable PackageKit update checking by default
gconftool-2 --direct --config-source=xml:readwrite:/etc/gconf/gconf.xml.defaults -s -t int /apps/gnome-packagekit/update-icon/frequency_get_updates "0" >/dev/null

# detecting disk partitions and logical volumes 
CreateDesktopIconHD()
{
cat > /home/$LIVECD_USER/Desktop/Local\ hard\ drives.desktop << EOF_HDicon
[Desktop Entry]
Encoding=UTF-8
Version=1.0
Type=Link
Name=Local hard drives
Name[en_US]=Local hard drives
URL=/mnt/disc
Icon=/usr/share/icons/gnome/32x32/devices/gnome-dev-harddisk.png
EOF_HDicon

chmod 755 /home/$LIVECD_USER/Desktop/Local\ hard\ drives.desktop
}

CreateDesktopIconLVM()
{
mkdir -p /home/$LIVECD_USER/Desktop >/dev/null

cat > /home/$LIVECD_USER/Desktop/Local\ logical\ volumes.desktop << EOF_LVMicon
[Desktop Entry]
Encoding=UTF-8
Version=1.0
Type=Link
Name=Local logical volumes
Name[en_US]=Local logical volumes
URL=/mnt/lvm
Icon=/usr/share/icons/gnome/32x32/devices/gnome-dev-harddisk.png
EOF_LVMicon

chmod 755 /home/$LIVECD_USER/Desktop/Local\ logical\ volumes.desktop
}

# don't mount disk partitions if 'nodiskmount' is given as a boot option
if ! strstr "\\\`cat /proc/cmdline\\\`" nodiskmount ; then
	MOUNTOPTION="ro"
	HARD_DISKS=\\\`egrep "[sh]d.\\\$" /proc/partitions | tr -s ' ' | sed 's/^  *//' | cut -d' ' -f4\\\`

	echo "Mounting hard disk partitions... "
	for DISK in \\\$HARD_DISKS; do
	    # Get the device and system info from fdisk (but only for fat and linux partitions).
	    FDISK_INFO=\\\`fdisk -l /dev/\\\$DISK | tr [A-Z] [a-z] | egrep "fat|linux" | egrep -v "swap|extended|lvm" | sed 's/*//' | tr -s ' ' | tr ' ' ':' | cut -d':' -f1,6-\\\`
	    for FDISK_ENTRY in \\\$FDISK_INFO; do
		PARTITION=\\\`echo \\\$FDISK_ENTRY | cut -d':' -f1\\\`
		MOUNTPOINT="/mnt/disc/\\\${PARTITION##/dev/}"
		mkdir -p \\\$MOUNTPOINT
		MOUNTED=FALSE

		# get the partition type
		case \\\`echo \\\$FDISK_ENTRY | cut -d':' -f2-\\\` in
		*fat*) 
		    FSTYPES="vfat"
		    EXTRAOPTIONS=",uid=500";;
		*)
		    FSTYPES="ext4 ext3 ext2"
		    EXTRAOPTIONS="";;
		esac

		# try to mount the partition
		for FSTYPE in \\\$FSTYPES; do
		    if mount -o "\\\${MOUNTOPTION}\\\${EXTRAOPTIONS}" -t \\\$FSTYPE \\\$PARTITION \\\$MOUNTPOINT &>/dev/null; then
			echo "\\\$PARTITION \\\$MOUNTPOINT \\\$FSTYPE noauto,\\\${MOUNTOPTION}\\\${EXTRAOPTIONS} 0 0" >> /etc/fstab
			echo -n "\\\$PARTITION "
			MOUNTED=TRUE
			CreateDesktopIconHD
		    fi
		done
		[ \\\$MOUNTED = "FALSE" ] && rmdir \\\$MOUNTPOINT
	    done
	done
	echo
fi

# don't mount logical volumes if 'nolvmmount' is given as a boot option
if ! strstr "\\\`cat /proc/cmdline\\\`" nolvmmount ; then
        MOUNTOPTION="ro"
	FSTYPES="ext4 ext3 ext2"
	echo "Scanning for logical volumes..."
	if ! lvm vgscan 2>&1 | grep "No volume groups"; then
	    echo "Activating logical volumes ..."
	    modprobe dm_mod >/dev/null
	    lvm vgchange -ay
	    LOGICAL_VOLUMES=\\\`lvm lvdisplay -c | sed "s/^  *//" | cut -d: -f1\\\`
	    if [ ! -z "\\\$LOGICAL_VOLUMES" ]; then
		echo "Making device nodes ..."
		lvm vgmknodes
		echo -n "Mounting logical volumes ... "
		for VOLUME_NAME in \\\$LOGICAL_VOLUMES; do
		    VG_NAME=\\\`echo \\\$VOLUME_NAME | cut -d/ -f3\\\`
		    LV_NAME=\\\`echo \\\$VOLUME_NAME | cut -d/ -f4\\\`
		    MOUNTPOINT="/mnt/lvm/\\\${VG_NAME}-\\\${LV_NAME}"
		    mkdir -p \\\$MOUNTPOINT

		    MOUNTED=FALSE
		    for FSTYPE in \\\$FSTYPES; do
			if mount -o \\\$MOUNTOPTION -t \\\$FSTYPE \\\$VOLUME_NAME \\\$MOUNTPOINT &>/dev/null; then
			    echo "\\\$VOLUME_NAME \\\$MOUNTPOINT \\\$FSTYPE defaults,\\\${MOUNTOPTION} 0 0" >> /etc/fstab
			    echo -n "\\\$VOLUME_NAME "
			    MOUNTED=TRUE
			    CreateDesktopIconLVM
			    break
			fi
		    done
		    [ \\\$MOUNTED = FALSE ] && rmdir \\\$MOUNTPOINT
		done
		echo

	    else
		echo "No logical volumes found"
	    fi
	fi
fi

# give back ownership to the default user
chown -R $LIVECD_USER:$LIVECD_USER /home/$LIVECD_USER
EOF_initscript


# bah, hal starts way too late
cat > /etc/rc.d/init.d/livesys-late << EOF_lateinitscript
#!/bin/bash
#
# live: Late init script for live image
#
# chkconfig: 345 99 01
# description: Late init script for live image.

. /etc/init.d/functions

if ! strstr "\\\`cat /proc/cmdline\\\`" liveimg || [ "\\\$1" != "start" ] || [ -e /.liveimg-late-configured ] ; then
    exit 0
fi

exists() {
    which \\\$1 >/dev/null 2>&1 || return
    \\\$*
}

touch /.liveimg-late-configured

# read some variables out of /proc/cmdline
for o in \\\`cat /proc/cmdline\\\` ; do
    case \\\$o in
    ks=*)
        ks="\\\${o#ks=}"
        ;;
    xdriver=*)
        xdriver="--set-driver=\\\${o#xdriver=}"
        ;;
    esac
done


########## my init script extensions #####################################

### QLogic firmware autoupdate - see <%post --nochroot> script ###

if strstr "\\\`cat /proc/cmdline\\\`" qlogic ; then
   plymouth --quit
   PATH=$PATH:/usr/local/bin
   export PATH
   echo "Installing FW"
   /mnt/live/qlogic/qlgc_fw_fc_8g-f50701-b213-e238_linux_32-64.bin -s
   read -p "Press any key to install EDC..."
   /mnt/live/qlogic/qlgc_fw_fc_8g-edc-brsw-2.00_linux_32-64.bin -s
   read -p "Press any key to reboot..."
   reboot
fi

##########################################################################

EOF_lateinitscript

# workaround avahi segfault (#279301)
touch /etc/resolv.conf
/sbin/restorecon /etc/resolv.conf

chmod 755 /etc/rc.d/init.d/livesys
/sbin/restorecon /etc/rc.d/init.d/livesys
/sbin/chkconfig --add livesys

chmod 755 /etc/rc.d/init.d/livesys-late
/sbin/restorecon /etc/rc.d/init.d/livesys-late
/sbin/chkconfig --add livesys-late

# go ahead and pre-make the man -k cache (#455968)
/usr/sbin/makewhatis -w

# save a little bit of space at least...
rm -f /var/lib/rpm/__db*
rm -f /boot/initrd*
rm -f /boot/initramfs*
# make sure there aren't core files lying around
rm -f /core*

# convince readahead not to collect
rm -f /.readahead_collect
touch /var/lib/readahead/early.sorted

# import RPM GPG keys
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-beta
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release

EOF_post

/bin/bash -x /root/post-install 2>&1 | tee /root/post-install.log

%end

%post --nochroot

########################################################################
# Create a sub-script so the output can be captured
# Must change "$" to "\$" and "`" to "\`" to avoid shell quoting
########################################################################
cat > /root/postnochroot-install << EOF_postnochroot
#!/bin/bash

# Copy licensing information
cp $INSTALL_ROOT/usr/share/doc/*-release-*/GPL $LIVE_ROOT/GPL

# add livecd-iso-to-disk utility on the LiveCD
# only works on x86, x86_64
if [ "\$(uname -i)" = "i386" -o "\$(uname -i)" = "x86_64" ]; then
  if [ ! -d \$LIVE_ROOT/LiveOS ]; then mkdir -p \$LIVE_ROOT/LiveOS ; fi
  cp /usr/bin/livecd-iso-to-disk \$LIVE_ROOT/LiveOS
fi

# customize boot menu entries
grep -B4 'menu default'  \$LIVE_ROOT/isolinux/isolinux.cfg > \$LIVE_ROOT/isolinux/default.txt
grep -B3 'xdriver=vesa'  \$LIVE_ROOT/isolinux/isolinux.cfg > \$LIVE_ROOT/isolinux/basicvideo.txt
grep -A3 'label check0'  \$LIVE_ROOT/isolinux/isolinux.cfg > \$LIVE_ROOT/isolinux/check.txt
grep -A2 'label memtest' \$LIVE_ROOT/isolinux/isolinux.cfg > \$LIVE_ROOT/isolinux/memtest.txt
grep -A2 'label local'   \$LIVE_ROOT/isolinux/isolinux.cfg > \$LIVE_ROOT/isolinux/localboot.txt

sed -i "/^menu hidden$/d"  \$LIVE_ROOT/isolinux/isolinux.cfg

sed "s/label linux0/label linuxtext0/"   \$LIVE_ROOT/isolinux/default.txt > \$LIVE_ROOT/isolinux/textboot.txt
sed -i "s/Boot/Boot (Text Mode)/"                                           \$LIVE_ROOT/isolinux/textboot.txt
sed -i "s/liveimg/liveimg 3/"                                               \$LIVE_ROOT/isolinux/textboot.txt
sed -i "/menu default/d"                                                    \$LIVE_ROOT/isolinux/textboot.txt

sed "s/label linux0/label install0/"     \$LIVE_ROOT/isolinux/default.txt > \$LIVE_ROOT/isolinux/install.txt
sed -i "s/Boot/Install/"                                                    \$LIVE_ROOT/isolinux/install.txt
sed -i "s/liveimg/liveimg liveinst noswap nolvmmount/"                      \$LIVE_ROOT/isolinux/install.txt
sed -i "s/ quiet / /"                                                       \$LIVE_ROOT/isolinux/install.txt
sed -i "s/ rhgb / /"                                                        \$LIVE_ROOT/isolinux/install.txt
sed -i "/menu default/d"                                                    \$LIVE_ROOT/isolinux/install.txt

sed "s/label linux0/label textinstall0/" \$LIVE_ROOT/isolinux/default.txt > \$LIVE_ROOT/isolinux/textinstall.txt
sed -i "s/Boot/Install (Text Mode)/"                                        \$LIVE_ROOT/isolinux/textinstall.txt
sed -i "s/liveimg/liveimg textinst noswap nolvmmount/"                      \$LIVE_ROOT/isolinux/textinstall.txt
sed -i "s/ quiet / /"                                                       \$LIVE_ROOT/isolinux/textinstall.txt
sed -i "s/ rhgb / /"                                                        \$LIVE_ROOT/isolinux/textinstall.txt
sed -i "/menu default/d"                                                    \$LIVE_ROOT/isolinux/textinstall.txt

sed "s/label linux0/label qlogic0/"     \$LIVE_ROOT/isolinux/default.txt >  \$LIVE_ROOT/isolinux/qlogic.txt
sed -i "s/Boot/QLogic FW 5.07.01/"                                          \$LIVE_ROOT/isolinux/qlogic.txt
sed -i "s/liveimg/liveimg qlogic/"                                          \$LIVE_ROOT/isolinux/qlogic.txt
sed -i "/menu default/d"                                                    \$LIVE_ROOT/isolinux/qlogic.txt


cat \$LIVE_ROOT/isolinux/default.txt \$LIVE_ROOT/isolinux/basicvideo.txt \$LIVE_ROOT/isolinux/check.txt \$LIVE_ROOT/isolinux/memtest.txt \$LIVE_ROOT/isolinux/localboot.txt > \$LIVE_ROOT/isolinux/current.txt
diff \$LIVE_ROOT/isolinux/isolinux.cfg \$LIVE_ROOT/isolinux/current.txt | sed '/^[0-9][0-9]*/d; s/^. //; /^---$/d' > \$LIVE_ROOT/isolinux/cleaned.txt
cat \$LIVE_ROOT/isolinux/cleaned.txt \$LIVE_ROOT/isolinux/default.txt \$LIVE_ROOT/isolinux/qlogic.txt \$LIVE_ROOT/isolinux/memtest.txt \$LIVE_ROOT/isolinux/localboot.txt > \$LIVE_ROOT/isolinux/isolinux.cfg
rm -f \$LIVE_ROOT/isolinux/*.txt

######################################################################################################
######################## Additional files  ###################

### QLogic FW 5.07.01 ###
if [ ! -d \$LIVE_ROOT/qlogic ]; then mkdir -p \$LIVE_ROOT/qlogic ; fi
cp /home/matvey/qlgc_fw_fc_8g-f50701-b213-e238_linux_32-64.bin \$LIVE_ROOT/qlogic/qlgc_fw_fc_8g-f50701-b213-e238_linux_32-64.bin
chmod +x \$LIVE_ROOT/qlogic/qlgc_fw_fc_8g-f50701-b213-e238_linux_32-64.bin
cp /home/matvey/qlgc_fw_fc_8g-edc-brsw-2.00_linux_32-64.bin \$LIVE_ROOT/qlogic/qlgc_fw_fc_8g-edc-brsw-2.00_linux_32-64.bin
chmod +x \$LIVE_ROOT/qlogic/qlgc_fw_fc_8g-edc-brsw-2.00_linux_32-64.bin

### DSA Linux 9.31  ###
if [ ! -d \$LIVE_ROOT/ibm ]; then mkdir -p \$LIVE_ROOT/ibm ; fi
cp /home/matvey/ibm_utl_dsa_dsytb31-9.30_portable_rhel6_i386.bin \$LIVE_ROOT/ibm/ibm_utl_dsa_dsytb31-9.30_portable_rhel6_i386.bin
chmod +x \$LIVE_ROOT/ibm/ibm_utl_dsa_dsytb31-9.30_portable_rhel6_i386.bin

### Brocade CNA  ###
if [ ! -d \$LIVE_ROOT/ibm ]; then mkdir -p \$LIVE_ROOT/ibm ; fi
cp /home/matvey/brcd_fw_cna_3.2.0.0_vmware_x86-64.bin \$LIVE_ROOT/ibm/brcd_fw_cna_3.2.0.0_vmware_x86-64.bin
cp /home/matvey/brcd_dd_fc_bfa-3.1.0.1_rhel6_32-64.tgz \$LIVE_ROOT/ibm/brcd_dd_fc_bfa-3.1.0.1_rhel6_32-64.tgz
chmod +x \$LIVE_ROOT/ibm/brcd_fw_cna_3.2.0.0_vmware_x86-64.bin

### IBM ASU  ###
if [ ! -d \$LIVE_ROOT/ibm ]; then mkdir -p \$LIVE_ROOT/ibm ; fi
cp -Rv -t \$LIVE_ROOT/ibm /home/matvey/ibm_utl_asu_asut80o-9.40_linux_i686



######################################################################################################

EOF_postnochroot

/bin/bash -x /root/postnochroot-install 2>&1 | tee /root/postnochroot-install.log

%end
