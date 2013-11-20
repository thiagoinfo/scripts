#! /bin/bash
#
# Скрипт конфигурации iptables для балансировщика dev-sppw-lb
# Сбрасывает конфигурацию iptables, добавляет правила из этого файла, делает service iptables save, service iptables restart
#
#

set -e

# Клиент балансироващика. На нем настроен default gw 10.76.157.200 (интерфейс eth1 балансировщика)
DEV_SPPW_APP1=10.76.157.62
TEST_SPPW_APP=10.76.157.64


###############################################################################
#
# filter table
#
# set default policy
iptables -t filter -F
iptables -t filter -P INPUT ACCEPT
iptables -t filter -P FORWARD ACCEPT
iptables -t filter -P OUTPUT ACCEPT

# filter FORWARD: enable forwarding for dev-sppw-app1
iptables -t filter  -A FORWARD -s ${DEV_SPPW_APP1} -j ACCEPT
iptables -t filter  -A FORWARD -d ${DEV_SPPW_APP1} -j ACCEPT

# filter FORWARD: enable forwarding for test-sppw-app
iptables -t filter  -A FORWARD -s ${TEST_SPPW_APP} -j ACCEPT
iptables -t filter  -A FORWARD -d ${TEST_SPPW_APP} -j ACCEPT

# drop rest FORWARD chain traffic
iptables -t filter  -A FORWARD -j NFLOG --nflog-group 1 --nflog-prefix "FORWARD DROP: "
iptables -t filter  -A FORWARD -j DROP

###############################################################################
#
# mangle table
#
iptables -t mangle -F

# don't balance broadcast and LAN traffic
iptables -t mangle -A PREROUTING -d 255.255.255.255 -j ACCEPT
iptables -t mangle -A PREROUTING -s 10.76.0.0/16 -d 10.76.0.0/16 -j ACCEPT

# balance TCP connections to 10 IP
iptables -t mangle -X
iptables -t mangle -N MARK_1
iptables -t mangle -N MARK_2
iptables -t mangle -N MARK_3
iptables -t mangle -N MARK_4
iptables -t mangle -N MARK_5
iptables -t mangle -N MARK_6
iptables -t mangle -N MARK_7
iptables -t mangle -N MARK_8
iptables -t mangle -N MARK_9
iptables -t mangle -N MARK_10

iptables -t mangle -A MARK_1  -j CONNMARK --set-mark 1
iptables -t mangle -A MARK_1  -j ACCEPT

iptables -t mangle -A MARK_2  -j CONNMARK --set-mark 2
iptables -t mangle -A MARK_2  -j ACCEPT

iptables -t mangle -A MARK_3  -j CONNMARK --set-mark 3
iptables -t mangle -A MARK_3  -j ACCEPT

iptables -t mangle -A MARK_4  -j CONNMARK --set-mark 4
iptables -t mangle -A MARK_4  -j ACCEPT

iptables -t mangle -A MARK_5  -j CONNMARK --set-mark 5
iptables -t mangle -A MARK_5  -j ACCEPT

iptables -t mangle -A MARK_6  -j CONNMARK --set-mark 6
iptables -t mangle -A MARK_6  -j ACCEPT

iptables -t mangle -A MARK_7  -j CONNMARK --set-mark 7
iptables -t mangle -A MARK_7  -j ACCEPT

iptables -t mangle -A MARK_8  -j CONNMARK --set-mark 8
iptables -t mangle -A MARK_8  -j ACCEPT

iptables -t mangle -A MARK_9  -j CONNMARK --set-mark 9
iptables -t mangle -A MARK_9  -j ACCEPT

iptables -t mangle -A MARK_10 -j CONNMARK --set-mark 10
iptables -t mangle -A MARK_10 -j ACCEPT

# probability caclucated as increasing sequence 1/N, 1/N-1, 1/N-2 ... 1/2, 1
# http://wiki.rsu.edu.ru/wiki/Iptables_load_balancing
# 0.1 0.111 0.125 0.143 0.167 0.2 0.25 0.333 0.5
#
iptables -t mangle -A PREROUTING -i eth1 -m state --state NEW,RELATED -m statistic --mode random --probability 0.1   -j MARK_10
iptables -t mangle -A PREROUTING -i eth1 -m state --state NEW,RELATED -m statistic --mode random --probability 0.111 -j MARK_9
iptables -t mangle -A PREROUTING -i eth1 -m state --state NEW,RELATED -m statistic --mode random --probability 0.125 -j MARK_8
iptables -t mangle -A PREROUTING -i eth1 -m state --state NEW,RELATED -m statistic --mode random --probability 0.143 -j MARK_7
iptables -t mangle -A PREROUTING -i eth1 -m state --state NEW,RELATED -m statistic --mode random --probability 0.167 -j MARK_6
iptables -t mangle -A PREROUTING -i eth1 -m state --state NEW,RELATED -m statistic --mode random --probability 0.2   -j MARK_5
iptables -t mangle -A PREROUTING -i eth1 -m state --state NEW,RELATED -m statistic --mode random --probability 0.25  -j MARK_4
iptables -t mangle -A PREROUTING -i eth1 -m state --state NEW,RELATED -m statistic --mode random --probability 0.333 -j MARK_3
iptables -t mangle -A PREROUTING -i eth1 -m state --state NEW,RELATED -m statistic --mode random --probability 0.5   -j MARK_2
iptables -t mangle -A PREROUTING -i eth1 -m state --state NEW,RELATED -j MARK_1

###############################################################################
#
# nat table
# 
iptables -t nat -F

# masquerade client IP to make load balancing work
iptables -t nat -A POSTROUTING -o eth0 ! -d 10.76.0.0/16 -m connmark --mark 2  -j NFLOG --nflog-group 1 --nflog-prefix "SNAT  2: "
iptables -t nat -A POSTROUTING -o eth0 ! -d 10.76.0.0/16 -m connmark --mark 2  -j SNAT --to-source 10.76.156.202
iptables -t nat -A POSTROUTING -o eth0 ! -d 10.76.0.0/16 -m connmark --mark 3  -j NFLOG --nflog-group 1 --nflog-prefix "SNAT  3: "
iptables -t nat -A POSTROUTING -o eth0 ! -d 10.76.0.0/16 -m connmark --mark 3  -j SNAT --to-source 10.76.156.203
iptables -t nat -A POSTROUTING -o eth0 ! -d 10.76.0.0/16 -m connmark --mark 4  -j NFLOG --nflog-group 1 --nflog-prefix "SNAT  4: "
iptables -t nat -A POSTROUTING -o eth0 ! -d 10.76.0.0/16 -m connmark --mark 4  -j SNAT --to-source 10.76.156.204
iptables -t nat -A POSTROUTING -o eth0 ! -d 10.76.0.0/16 -m connmark --mark 5  -j NFLOG --nflog-group 1 --nflog-prefix "SNAT  5: "
iptables -t nat -A POSTROUTING -o eth0 ! -d 10.76.0.0/16 -m connmark --mark 5  -j SNAT --to-source 10.76.156.205
iptables -t nat -A POSTROUTING -o eth0 ! -d 10.76.0.0/16 -m connmark --mark 6  -j NFLOG --nflog-group 1 --nflog-prefix "SNAT  6: "
iptables -t nat -A POSTROUTING -o eth0 ! -d 10.76.0.0/16 -m connmark --mark 6  -j SNAT --to-source 10.76.156.206
iptables -t nat -A POSTROUTING -o eth0 ! -d 10.76.0.0/16 -m connmark --mark 7  -j NFLOG --nflog-group 1 --nflog-prefix "SNAT  7: "
iptables -t nat -A POSTROUTING -o eth0 ! -d 10.76.0.0/16 -m connmark --mark 7  -j SNAT --to-source 10.76.156.207
iptables -t nat -A POSTROUTING -o eth0 ! -d 10.76.0.0/16 -m connmark --mark 8  -j NFLOG --nflog-group 1 --nflog-prefix "SNAT  8: "
iptables -t nat -A POSTROUTING -o eth0 ! -d 10.76.0.0/16 -m connmark --mark 8  -j SNAT --to-source 10.76.156.208
iptables -t nat -A POSTROUTING -o eth0 ! -d 10.76.0.0/16 -m connmark --mark 9  -j NFLOG --nflog-group 1 --nflog-prefix "SNAT  9: "
iptables -t nat -A POSTROUTING -o eth0 ! -d 10.76.0.0/16 -m connmark --mark 9  -j SNAT --to-source 10.76.156.209
iptables -t nat -A POSTROUTING -o eth0 ! -d 10.76.0.0/16 -m connmark --mark 10 -j NFLOG --nflog-group 1 --nflog-prefix "SNAT 10: "
iptables -t nat -A POSTROUTING -o eth0 ! -d 10.76.0.0/16 -m connmark --mark 10 -j SNAT --to-source 10.76.156.210
iptables -t nat -A POSTROUTING -o eth0 ! -d 10.76.0.0/16                       -j NFLOG --nflog-group 1 --nflog-prefix "SNAT  1: "
iptables -t nat -A POSTROUTING -o eth0 ! -d 10.76.0.0/16                       -j SNAT --to-source 10.76.156.201

###############################################################################
service iptables save
service iptables restart

echo 'Filter table'
iptables -t filter -L
echo

echo 'Mangle table'
iptables -t mangle -L
echo

echo 'NAT table'
iptables -t nat -L
