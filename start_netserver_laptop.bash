#!/usr/bin/bash

# https://flent.org/intro.html#quick-start

vlans=(100 101 102 103 104 105)

for x in "${vlans[@]}"; do
	echo "######---------------------"
	echo "Starting netserver in network: ${x}"
	echo ip netns exec network"${x}" netserver &
	ip netns exec network"${x}" netserver &
done

echo "started netserver"
