#!/usr/bin/bash

vlans=(100 101 102 103 104 105)
devices=(pi4 pi3b jetson nanopi-neo3 nanopi-r5c asus2)

for ((i = 0; i < ${#vlans[@]}; i++)); do
	x="${vlans[${i}]}"
	y=$((x + 100))

	echo "######---------------------"
	echo \
		ip netns exec network"${y}" \
		flent rrul \
		-p all_scaled \
		-l 600 \
		-H 172.16."${x}".10 \
		-t 172.16."${x}".10_"${devices[${i}]}" \
		-o "${devices[${i}]}".png

	ip netns exec network"${y}" \
		flent rrul \
		-p all_scaled \
		-l 600 \
		-H 172.16."${x}".10 \
		-t 172.16."${x}".10_"${devices[${i}]}" \
		-o "${devices[${i}]}".png

done

#ip netns exec networkY iperf -c 172.16.100.10 -i 10 -t 300 --parallel 10 --dualtest
