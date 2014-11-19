FROM centos:centos6

RUN yum clean all && yum -q -y install http://yum.postgresql.org/9.1/redhat/rhel-6-x86_64/pgdg-centos91-9.1-4.noarch.rpm && \
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-PGDG-91 && \
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6 && \
    yum -q -y install postgresql91 postgresql91-server tar man which mc rsync lvm2 device-mapper-multipath e2fsprogs openssh-clients && \
    yum clean all && \
    sed -i.bak 's/udev_sync.*/udev_sync = 0/;s/udev_rules.*/udev_rules = 0/;s/verify_udev_operations.*/verify_udev_operations = 1/' /etc/lvm/lvm.conf

ADD dist /dist

RUN ln -sf /bin/true /sbin/start && ln -sf /bin/true /sbin/stop && \
    yum -q -y install /dist/runit-2.1.2-1.el6.x86_64.rpm /dist/jre-7u72-linux-x64.rpm && \
    /dist/xivGUI-4.4.0.2-build2-linux64.bin -i silent -f /dist/xcli_install.response && \
    /dist/4.1.0.0-TIV-TSFCM-Linux.bin -i silent -f /dist/fcm_4.1_install.response && \
    yum -q -y install /opt/tivoli/tsfcm/acs/gskit_install/tivoli.storage.fcm-tsfcm-4.1.0.0-1.x86_64.rpm /opt/tivoli/tsfcm/acs/gskit_install/gskcrypt64-8.0.14.28.linux.x86_64.rpm /opt/tivoli/tsfcm/acs/gskit_install/gskssl64-8.0.14.28.linux.x86_64.rpm && \
    yum clean all


