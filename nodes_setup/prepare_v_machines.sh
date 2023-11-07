#!/usr/bin/env bash

# install packages
ssh v01 "apt update -y; apt install bind9 haproxy -y"
ssh v02 "apt update -y; apt install bind9 haproxy -y"
ssh v03 "apt-get update; apt-get install apache2 php -y"

# copy configs
scp haproxy.cfg v01:/etc/haproxy/
scp haproxy.cfg v02:/etc/haproxy/
scp db.local.v01 v01:/etc/bind/db.local
scp db.local.v02 v02:/etc/bind/db.local
scp index.php v03:/var/www/html/index.php

# stop services managed by pacemanker
ssh v01 "systemctl stop named"
ssh v02 "systemctl stop named"
ssh v01 "systemctl stop haproxy"
ssh v02 "systemctl stop haproxy"

# restart apache2 on node v03
ssh v03 "systemctl restart apache2"

# disable services managed by pacemaker
ssh v01 "systemctl disable haproxy"
ssh v02 "systemctl disable haproxy"
ssh v01 "systemctl disable named"
ssh v02 "systemctl disable named"

# enable apache on v03 node
ssh v03 "systemctl enable apache2"

# reboot
ssh v02 "reboot"
ssh v01 "reboot"


