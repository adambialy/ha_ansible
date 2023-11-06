Test setup 2 node corosync/pacemaker cluster with external www server.
----------------------------------------------------------------------

prerequsites:

3 nodes running ubuntu or debian. Simple script in nodes_setup directory will set named, haproxy and apache on nodes. (TODO - ansible role for setting up nodes)
For simplicity add all nodes to /etc/hosts

scenario:

- tiny 2 node cluster (not ha strictly speaking as needs to be 3 nodes at least)
- v01 & v02 - corosync pacemaker nodes (ip ending 201, and 202)
- v03 - ub22 running apache (ip ending 203)
- cluster has 2 virtual ip addresses (ending 204 and 205) 
- also configured 2 services in pacemaker
- both services managed by pacemaker ocf systemd (ocf - open cluster framework)
- two services are: - dns (named) , - ldap (haproxy, backend pointing to node v03 apache)
- each service is "bonded" with prefered virtual ip address
- each service has prefered node and "backup" node


ansible
-------

All variables configured in inventory file

ansible run:

ansible-playbook ha_cluster.yaml -i ha_cluster_inventory.yaml


After succesful run, you should have situation like this:

'''pcs status'''

```
 pcs status

Cluster name: aio
Cluster Summary:
  * Stack: corosync
  * Current DC: v01 (version 2.1.2-ada5c3b36e2) - partition with quorum
  * Last updated: Mon Nov  6 17:30:17 2023
  * Last change:  Mon Nov  6 17:21:52 2023 by root via cibadmin on v01
  * 2 nodes configured
  * 4 resource instances configured

Node List:
  * Online: [ v01 v02 ]

Full List of Resources:
  * vip-dns	(ocf:heartbeat:IPaddr2):	 Started v01
  * vip-ldap	(ocf:heartbeat:IPaddr2):	 Started v02
  * srv-named	(systemd:named):	 Started v01
  * srv-haproxy	(systemd:haproxy):	 Started v02

Daemon Status:
  corosync: active/enabled
  pacemaker: active/enabled
  pcsd: active/enabled
```

lets test if that's true

```
ssh v01 "ps ax" | grep bind 
  12015 ?        Ssl    0:00 /usr/sbin/named -u bind
  12146 pts/0    S+     0:00 vim /etc/bind/db.local

ssh v02 "ps ax" | grep bind
```

Process bind is running on v01, but isn't running on v02

Test if dns server is returning anything.

```
dig +time=5 +short @v02 v.localhost    
;; connection timed out; no servers could be reached

chi ~/corosync_test $ dig +time=5 +short @v01 v.localhost
127.0.1.1
```

dig only returns values for "v.local" from v01 (127.0.1.1 - see named.conf)

Lets check if dig against vip is returning anything

```
dig +time=5 +short @192.168.69.203 v.localhost
127.0.1.1
```

It's returning A record v.local from node 1.


haproxy/apache

```
ssh v01 "ps ax" | grep haproxy
ssh v02 "ps ax" | grep haproxy
   1258 ?        Ss     0:00 /usr/sbin/haproxy -Ws -f /etc/haproxy/haproxy.cfg -p /run/haproxy.pid -S /run/haproxy-master.sock
   1260 ?        Sl     0:00 /usr/sbin/haproxy -Ws -f /etc/haproxy/haproxy.cfg -p /run/haproxy.pid -S /run/haproxy-master.sock
```

process haproxy is not running on v01, and running on v02.

```
curl 192.168.69.204
connection comming from - 192.168.69.202  
```

curl test against vip, shows that node which is initiating connection to apache (on v03) is v02.

all good.

last look at the resources

'''pcs resource config'''

```
pcs resource config 
 Resource: vip-dns (class=ocf provider=heartbeat type=IPaddr2)
  Attributes: cidr_netmask=32 ip=192.168.69.203 nic=ens160
  Meta Attrs: migration-threshold=10 target-role=Started
  Operations: monitor interval=5s (vip-dns-monitor-5s)
 Resource: vip-ldap (class=ocf provider=heartbeat type=IPaddr2)
  Attributes: cidr_netmask=32 ip=192.168.69.204 nic=ens160
  Meta Attrs: migration-threshold=10 target-role=Started
  Operations: monitor interval=5s (vip-ldap-monitor-5s)
 Resource: srv-named (class=systemd type=named)
  Operations: monitor interval=60 timeout=100 (srv-named-monitor-interval-60)
              start interval=0s timeout=100 (srv-named-start-interval-0s)
              stop interval=0s timeout=100 (srv-named-stop-interval-0s)
 Resource: srv-haproxy (class=systemd type=haproxy)
  Operations: monitor interval=60 timeout=100 (srv-haproxy-monitor-interval-60)
              start interval=0s timeout=100 (srv-haproxy-start-interval-0s)
              stop interval=0s timeout=100 (srv-haproxy-stop-interval-0s)

```


Let's brake some of the configs ans see how it all failing over...

Remove some semicolon from bind config /etc/bind/named.conf.options on node v01.

check if the config is broken:

```
named-checkconf /etc/bind/named.conf
/etc/bind/named.conf.options:24: missing ';' before '}'
```

it is broke indeed, restart named

```
systemctl restart named
Job for named.service failed because the control process exited with error code.
See "systemctl status named.service" and "journalctl -xeu named.service" for details.
```

```
pcs status
Cluster name: aio
Cluster Summary:
  * Stack: corosync
  * Current DC: v01 (version 2.1.2-ada5c3b36e2) - partition with quorum
  * Last updated: Mon Nov  6 18:00:48 2023
  * Last change:  Mon Nov  6 17:21:52 2023 by root via cibadmin on v01
  * 2 nodes configured
  * 4 resource instances configured

Node List:
  * Online: [ v01 v02 ]


Full List of Resources:
  * vip-dns	(ocf:heartbeat:IPaddr2):	 Started v02
  * vip-ldap	(ocf:heartbeat:IPaddr2):	 Started v02
  * srv-named	(systemd:named):	 Started v02
  * srv-haproxy	(systemd:haproxy):	 Started v02

Failed Resource Actions:
  * srv-named start on v01 returned 'error' because 'failed' at Mon Nov  6 18:00:06 2023 after 2.417s
```

service srv-named migrated to v02 together with it's vip.

Now repair config and move service back to prefered node

```
named-checkconf /etc/bind/named.conf ; echo $?
0
```

config check ok.

'''pcs resource cleanup'''

```
pcs resource cleanup srv-named
Cleaned up srv-named on v02
Cleaned up srv-named on v01
Waiting for 1 reply from the controller
... got reply (done)
```

watch /var/log/pacemaker/pacemake.log to see messages... and voila

```
pcs status resources 
  * vip-dns	(ocf:heartbeat:IPaddr2):	 Started v01
  * vip-ldap	(ocf:heartbeat:IPaddr2):	 Started v02
  * srv-named	(systemd:named):	 Started v01
  * srv-haproxy	(systemd:haproxy):	 Started v02
```

All back to original config.


Lets test haproxy failing

currently node v02 replying:

```
curl 192.168.69.202
connection comming from - 192.168.69.202 
```
and corresponding vip

```
curl 192.168.69.204
connection comming from - 192.168.69.202 
```

Again, brake slightly config (add one letter to backend for example), and restart the service

```
systemctl restart haproxy
Job for haproxy.service failed because the control process exited with error code.
See "systemctl status haproxy.service" and "journalctl -xeu haproxy.service" for details.
```

pacemaker log showing the action...

```
Nov 06 18:24:18.011 v01 pacemaker-based     [890] (cib_process_request) 	info: Completed cib_modify operation for section status: OK (rc=0, origin=v02/crmd/45, version=0.18.31)
Nov 06 18:24:18.011 v01 pacemaker-controld  [895] (process_graph_event) 	info: Transition 14 action 2 (srv-haproxy_stop_0 on v02) confirmed: ok | rc=0 call-id=35
Nov 06 18:24:18.015 v01 pacemaker-controld  [895] (te_rsc_command) 	notice: Initiating start operation srv-haproxy_start_0 locally on v01 | action 12
```

and...

```
pcs status resources 
  * vip-dns	(ocf:heartbeat:IPaddr2):	 Started v01
  * vip-ldap	(ocf:heartbeat:IPaddr2):	 Started v01
  * srv-named	(systemd:named):	 Started v01
  * srv-haproxy	(systemd:haproxy):	 Started v01
```
srv-haproxy moved to node v01, quick curl showing that connection to apache comming from node v01

```
curl 192.168.69.204
connection comming from - 192.168.69.201
```

haproxy migrated to node v01 together with vip.


GUI
---

Web interface is listening on port 2224 on each cluster node. Authentiaction is use hacluster with configured pam password.
In ansible it's hacluster_user.yaml . Generate password by: 
```
python -c 'import crypt; print crypt.crypt("yorpassword", "$1$hacluste$")'
```

