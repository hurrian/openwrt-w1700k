#!/bin/sh

N_DSA_PORTS=4
LAN_DEV=eth0
WAN_DEV=eth1
# QoS channel ID for WAN destionation
WAN_CHANNEL_ID=4
RATE=50
NSTRICT=4
QUANTA="quanta 1514 1514 1514 1514"
PRIOMAP="priomap 4 5 6 7 3 2 1 0"
PORT0=6001
PORT1=6002
PRIO0=0
PRIO1=5

# LAN -> WAN

# Remove previous configuration
{
for i in $(seq $N_DSA_PORTS); do
	tc filter del dev lan$i egress
	tc filter del dev lan$i ingress
	tc qdisc del dev $LAN_DEV parent 10:$i handle $i:
	tc class del dev $LAN_DEV parent 10: classid 10:$i
done
tc qdisc del dev $LAN_DEV root handle 10:

tc qdisc replace dev $LAN_DEV root handle 10: htb offload
for i in $(seq $N_DSA_PORTS); do
	# HTB class qdisc [10:x] (associated to hw QoS channels)
	tc class add dev $LAN_DEV parent 10: classid 10:$i		\
		htb rate "$((RATE*i))mbit" ceil "$((RATE*i))mbit"
	# ETS qdisc [1:x] (ETS bands associated to hw QoS per-channel queues)
	tc qdisc replace dev $LAN_DEV parent 10:$i handle $i: 		\
		ets bands 8 strict $NSTRICT $QUANTA $PRIOMAP

	# add CLSACT qdisc on DSA ports
	tc qdisc add dev lan$i clsact
	# TC filters - skb priority is associated to ETS bands
	tc filter add dev lan$i protocol ip egress		\
		flower ip_proto tcp dst_port $PORT0		\
		action skbedit priority 0x${i}000$((PRIO0+1))
	tc filter add dev lan$i protocol ip egress		\
		flower ip_proto tcp dst_port $PORT1		\
		action skbedit priority 0x${i}000$((PRIO1+1))
	tc filter add dev lan$i protocol ip ingress		\
		flower ip_proto tcp dst_port $PORT0		\
		action skbedit priority $PRIO0
	tc filter add dev lan$i protocol ip ingress		\
		flower ip_proto tcp dst_port $PORT1		\
		action skbedit priority $PRIO1
done

# WAN -> LAN
tc filter del dev $WAN_DEV egress
tc filter del dev $WAN_DEV ingress
tc qdisc del dev $WAN_DEV parent 10:$WAN_CHANNEL_ID handle $WAN_CHANNEL_ID:
tc class del dev $WAN_DEV parent 10: classid 10:$WAN_CHANNEL_ID
tc qdisc del dev $WAN_DEV root handle 10: htb offload

tc qdisc replace dev $WAN_DEV root handle 10: htb offload
# HTB class qdisc [10:1] (associated to hw QoS channels)
tc class add dev $WAN_DEV parent 10: classid 10:$WAN_CHANNEL_ID			\
	htb rate "${RATE}mbit" ceil "${RATE}mbit"
# ETS qdisc [1:1] (ETS bands associated to hw QoS per-channel queues)
tc qdisc replace dev $WAN_DEV parent 10:$WAN_CHANNEL_ID handle $WAN_CHANNEL_ID: \
	ets bands 8 strict $NSTRICT $QUANTA $PRIOMAP

tc qdisc add dev $WAN_DEV clsact
tc filter add dev $WAN_DEV protocol ip egress				\
	flower ip_proto tcp dst_port $PORT0				\
	action skbedit priority 0x${WAN_CHANNEL_ID}000$((PRIO0+1))
tc filter add dev $WAN_DEV protocol ip egress				\
	flower ip_proto tcp dst_port $PORT1				\
	action skbedit priority 0x${WAN_CHANNEL_ID}000$((PRIO1+1))
tc filter add dev $WAN_DEV protocol ip ingress				\
	flower ip_proto tcp dst_port $PORT0				\
	action skbedit priority $PRIO0
tc filter add dev $WAN_DEV protocol ip ingress				\
	flower ip_proto tcp dst_port $PORT1				\
	action skbedit priority $PRIO1
} > /dev/null 2>&1

sysctl -w net.ipv4.ip_forward_update_priority=0
