
Test setup 2 node corosync/pacemaker cluster with external www server.
----------------------------------------------------------------------

3 nodes:

01 & 02 - corosync pacemaker nodes
03 - ub22 running apache

01 and 02 has 2 virtual ip addresses and 2 configured services in pacemaker managed by pacemaker ocf systemd (ocf - open cluster framework)

two services are:
- bind
- haproxy backend pointing to node 03


ansible run
-----------

ansible-playbook ha_cluster.yaml -i ha_cluster_inventory.yaml
