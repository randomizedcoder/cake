#!/usr/bin/bash

vlans=(100 101 102 103 104 105)

for x in "${vlans[@]}"; do
	ip netns exec network"${x}" iperf --server --daemon --ipv6_domain
done

echo "started iperf server"
