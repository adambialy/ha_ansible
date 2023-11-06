Role Name
=========

Corosync + pacemaker installation to keep VIP's

<h2>Example two node setup</h2>

Install Corosync and Pacemaker on both nodes: You can install these packages from the official repositories of your operating system. For example, if you are using Ubuntu, you can use the following command to install these packages:

```
sudo apt-get install corosync pacemaker
```

Configure Corosync on both nodes: Corosync is a messaging layer that enables communication between the nodes in the cluster. You need to configure it on both nodes by editing the Corosync configuration file /etc/corosync/corosync.conf. Here is an example of a simple configuration file:

```
totem {
    version: 2
    secauth: off
    cluster_name: mycluster
    transport: udpu
}

nodelist {
    node {
        ring0_addr: 192.168.1.101
        name: node1
    }
    node {
        ring0_addr: 192.168.1.102
        name: node2
    }
}
```
In this example, we have configured Corosync with the udpu transport, which is suitable for two-node clusters. We have also specified the IP addresses and names of the two nodes in the cluster.

Configure Pacemaker on both nodes: Pacemaker is a cluster resource manager that manages the availability of the virtual IP address. You need to configure it on both nodes by editing the Pacemaker configuration file /etc/pacemaker/crm.conf. Here is an example of a simple configuration file:


```
pcs_cluster {
    use_mgmtd: false
    node node1
    node node2
}
```

In this example, we have specified the names of the two nodes in the cluster.

Create the virtual IP resource: You can create the virtual IP resource using the pcs command-line tool. Here is an example command:

```
sudo pcs resource create myvip ocf:heartbeat:IPaddr2 ip=192.168.1.100 nic=eth0
```

This command creates a resource called myvip that uses the IPaddr2 agent to manage the virtual IP address 192.168.1.100. The nic parameter specifies the network interface that will be used to manage the IP address.

Configure the resource constraints: You need to specify the constraints that determine which node will be the primary node for the virtual IP resource. Here is an example command:

```
sudo pcs constraint location myvip prefers node1=100
```

This command specifies that the virtual IP resource should run on node1 unless it is unavailable.

Start the cluster: You can start the cluster using the pcs command-line tool. Here is an example command:

```
 sudo pcs cluster start --all
```

This command starts the Corosync and Pacemaker services on both nodes and starts the cluster.

That's it! You should now have a two-node cluster with a virtual IP address managed by Pacemaker.



<h2>Example service</h2>

Create a BIND resource agent: Pacemaker doesn't come with a built-in BIND resource agent, so you need to create a custom resource agent to monitor the availability of BIND. You can use the following script as a starting point:

bash
```
#!/bin/bash

# Check if named is running
if systemctl status named > /dev/null
then
    exit 0
else
    exit 1
fi
```

Save this script as /usr/local/bin/named.sh and make it executable:


```
sudo chmod +x /usr/local/bin/named.sh
```
Create a BIND resource: Now you can create a resource for BIND using the resource agent you just created.

```
sudo pcs resource create named ocf:heartbeat:script \
    op monitor interval=10s \
    op start timeout=60s \
    op stop timeout=60s \
    user="bind" \
    group="bind" \
    script="/usr/local/bin/named.sh"
```

This command creates a resource named named using the ocf:heartbeat:script resource agent. The op monitor command specifies that the resource should be monitored every 10 seconds, and the op start and op stop commands specify the timeouts for starting and stopping the resource. The user and group options specify the user and group that should be used to run the resource agent, and the script option specifies the path to the BIND resource agent script.

Create a virtual IP resource: Now you can create a virtual IP resource that will be moved between nodes as needed.

```
sudo pcs resource create named-vip ocf:heartbeat:IPaddr2 \
    ip=192.168.1.100 \
    cidr_netmask=24 \
    op monitor interval=10s

This command creates a virtual IP resource named named-vip using the ocf:heartbeat:IPaddr2 resource agent. The ip and cidr_netmask options specify the IP address and subnet mask for the virtual IP address, and the op monitor command specifies that the resource should be monitored every 10 seconds.
```
Create a resource group: Now you can create a resource group that includes the BIND resource and the virtual IP resource.

```
sudo pcs resource group add named-group named named-vip
```

Configure colocation constraints: Now you can create a colocation constraint that specifies that the BIND resource and the virtual IP resource must be on the same node.

```
sudo pcs constraint colocation add named-group with named-vip
```

Configure order constraints: Now you can create an order constraint that specifies that the BIND resource must start before the virtual IP resource.

```
sudo pcs constraint order start named then start named-vip
```
Configure monitoring and migration: Finally, you should configure the BIND resource to monitor the availability of BIND and to automatically move the virtual IP address to another node if BIND becomes unavailable. You can use the following commands:

```
sudo pcs property set stonith-enabled=false
sudo pcs resource op add named monitor interval
```



Requirements
------------



Role Variables
--------------



```
        vips:
          - name: vip1
            vip_ip: 192.168.69.241
            vip_prefer: aio-01-dev
            vip_int: ens192
            vip_service: squid
          - name: vip2
            vip_ip: 192.168.69.242
            vip_prefer: aio-02-dev
            vip_int: ens192
            vip_service: nexus3
          - name: vip3
            vip_ip: 192.168.69.243
            vip_prefer: aio-01-dev
            vip_int: ens192
            vip_service: ldap
          - name: vip4
            vip_ip: 192.168.69.244
            vip_prefer: aio-02-dev
            vip_int: ens192
            vip_service: something

```
