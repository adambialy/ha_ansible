
Test setup 2 node corosync/pacemaker cluster with external www server.
----------------------------------------------------------------------

3 nodes:

01 & 02 - corosync pacemaker nodes
03 - ub22 running apache

01 and 02 has 2 virtual ip addresses and 2 configured services in pacemaker managed by pacemaker ocf systemd (ocf - open cluster framework)

two services are:
- bind
- haproxy backend pointing to node 03


ansible
-------

All variables configured in inventory file


ansible run:

ansible-playbook ha_cluster.yaml -i ha_cluster_inventory.yaml


after succesful ansible run you should have situation like this:

`pcs status`


```Cluster name: aio
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




