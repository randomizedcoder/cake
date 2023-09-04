#!/usr/bin/bash

vlans=(100 101 102 103 104 105)

for x in "${vlans[@]}"; do
	y=$((x + 100))
	ip netns exec network"${y}" \
		iperf \
		--client 172.16."${x}".10 \
		--interval 10 \
		--time 600 \
		--parallel 20 \
		--dualtest \
		--enhanced
done

#ip netns exec networkY iperf -c 172.16.100.10 -i 10 -t 300 --parallel 10 --dualtest
