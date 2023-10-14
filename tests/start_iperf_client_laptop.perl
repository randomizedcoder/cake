#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;

# use Data::Dumper;
# print Dumper(%data);

my $iperf_interval = 30;
# 1 minute - recommended for testing this script
#my $run_time = 60;
#my $run_time = 120;
#10 minutes - recommended for testing
my $run_time = 600;
my $parallel = 20;

GetOptions ("iperf_interval=i" => \$iperf_interval,
            "run_time=i"   => \$run_time,
            "parallel=i"  => \$parallel)
or die("Error in command line arguments\n");

my %outputs = ();
my %timestamps = ();
my $device_previous = "";
my $qdisc_previous = "";

my $timestamp = chomp(`date --utc +"\%Y_\%m_\%d_\%H:\%M:\%S"`);
print("timestamp:$timestamp\n");
#timestamp=$(date --utc +"%Y_%m_%d_%H:%M:%S.%N")

$timestamps{ "start" } = chomp(`date --utc +\%s`);
print("\$timestamps{ \"start\" }:$timestamps{ \"start\" }\n");

my $subnet_octet_a = 172;
my $subnet_octet_b = 16;

my $vlan_start = 100;
my $vlan_addition = 50;

print("subnet_octet_a:$subnet_octet_a\n");
print("subnet_octet_b:$subnet_octet_b\n");
print("vlan_start:$vlan_start\n");
print("vlan_addition:$vlan_addition\n");

my $devices_file = "./script_configuration/devices.txt";
open(my $handle, '<', $devices_file);
chomp(my @devices_ordered = <$handle>);
close $handle;
#my @devices = qw(pi4 pi3b jetson-nano nanopi-neo3 nanopi-r5c nanopi-r2s nanopi-r1 asus-cn60-2);
# fix me - temp for testing
#my @devices = qw(pi4);
use List::Util 'shuffle';
my @devices = shuffle(@devices_ordered);
print("## devices:@devices\n");

my @qdiscs = qw(noqueue pfifo_fast fq fq_codel cake20 cake40);
#fix me - temp for testing
#my @qdiscs = (noqueue pfifo_fast fq_codel);
print("## qdiscs:@qdiscs\n");

my @laptops = qw(3rd ryzen);
print("## laptops:@laptops\n");

print("cd /home/das/cake/ || exit\n");
`cd /home/das/cake/ || exit`;

print("mkdir /tmp/output_$timestamp\n");
`mkdir /tmp/output_$timestamp`;

while (my ($device_i, $device) = each @devices) {

	print("mkdir /tmp/output_$timestamp/$device\n");
	`mkdir /tmp/output_$timestamp/$device`;

	if ( $device_previous != $device ) {
		$timestamps{ $device }{ "start" } = chomp(`date --utc +\%s`);
		print("#-------------------------------------\n");
		print("\$timestamps{ $device }{ \"start\" } = $timestamps{ $device }{ \"start\" }\n");
		$device_previous = $device;
	}

	while (my ($qdisc_i, $qdisc) = each @qdiscs) {

		if ($qdisc_previous != $qdisc) {
			$timestamps{ $device}{$qdisc}{ "start" } = chomp(`date --utc +\%s`);
			print("#-------------------------------------\n");
			print("\$timestamps{ $device }{ $qdisc }{ \"start\" } = $timestamps{ $device }{ $qdisc }{ \"start\" }\n");
			$qdisc_previous = $qdisc;
		}

		my $namespace = ( $device_i * $vlan_start ) + $qdisc_i;
		#my $vlan = $namespace

		my $octet_a = $subnet_octet_a;
		my $octet_b = $subnet_octet_b + $device_i;
		my $octet_c = $qdisc_i + $vlan_addition;
		my $octet_d = 10;

		print("device:$device qdisc:$qdisc namespace:$namespace vlan:$vlan octet_a:$octet_a octet_b:$octet_b octet_c:$octet_c octet_d:$octet_d\n");

		print("#---------------------------------------------------------------\n");
		my $stage = "before";

		ansible_command( \%outputs, \%timestamps, $device, $qdisc, "ansible_ping_before_reboot", "ansible $device -i ./device_info/ansible_hosts -m ping");

		ansible_command( \%outputs, \%timestamps, $device, $qdisc, "ansible_device_reboot", "ansible $device -i ./device_info/ansible_hosts -m reboot --become");

		ansible_command( \%outputs, \%timestamps, $device, $qdisc, "ansible_ping_after_reboot", "ansible $device -i ./device_info/ansible_hosts -m ping");

		ansible_command( \%outputs, \%timestamps, $device, $qdisc, "ansible_configure_qdisc", "ansible $device -i ./device_info/ansible_hosts -m script -a ./cake.bash");

		ansible_command( \%outputs, \%timestamps, $device, $qdisc, "icmp_ping_$stage", "ip netns exec network$namespace ping -c 10 -w 1 $octet_a.$octet_b.$octet_c.$octet_d");

		gather_details_for_tests_from_device( \%outputs, \%timestamps, $device, $qdisc, $stage, $timestamp );
		gather_details_for_tests_from_laptops( \%outputs, \%timestamps, $device, $qdisc, $stage, $timestamp );

		my $step = "iperf";
		print("## Step:$step\n");
		print("##----------------------------------------------!!!!! woot woot");
		print("##device:$device qdisc:$qdisc namespace:$namespace vlan:$vlan $octet_a.$octet_b.$octet_c.$octet_d\/24");
		$timestamps{ $device }{ $qdisc }{ $step }{ $stage } = chomp(`date --utc +\%s`);

		$outputs{ $device }{ $qdisc }{ $step } = `sudo ip netns exec network$namespace \
				iperf \
				--client $octet_a.$octet_b.$octet_c.$octet_d \
				--interval $iperf_interval \
				--time $run_time \
				--parallel $parallel \
				--dualtest \
				--enhanced \
				--sum-only`;

		$timestamps{ $device }{ $qdisc }{ $step }{ "after" } = chomp(`date --utc +\%s`);

		$stage = "after";
		gather_details_for_tests_from_device( \%outputs, \%timestamps, $device, $qdisc, $stage, $timestamp);
		gather_details_for_tests_from_laptops( \%outputs, \%timestamps, $device, $qdisc, $stage, $timestamp);

		ansible_command( \%outputs, \%timestamps, $device, $qdisc, "icmp_ping_$stage", "ip netns exec network$namespace ping -c 10 -w 1 $octet_a.$octet_b.$octet_c.$octet_d");

		$timestamps{ $device }{ $qdisc }{ "end" } = chomp(`date --utc +\%s`);
		$timestamps{ $device }{ $qdisc }{ "duration" } = $timestamps{ $device}{ $qdisc} { "end" } - $timestamps{ $device}{ $qdisc }{ "start" };
		$timestamps{ $device }{ $qdisc }{ "duration_mins" } = $timestamps{ $device}{ $qdisc }{ "duration" } / 60;
		print("## device:$device qdisc:$qdisc duration:$timestamps{ $device}{ $qdisc }{ \"duration\" } duration_mins:$timestamps{ $device }{ $qdisc}{ \"duration_mins\" }\n");

	}

	$timestamps{ $device}{ "end" } = chomp(`date --utc +\%s`);
	$timestamps{ $device}{ "duration" } = $timestamps{ $device}{ "end" } - $timestamps{ $device }{ "start" };
	$timestamps{ $device}{ "duration_mins" } = $timestamps{ $device }{ "duration" } / 60;
	print("## device:$device duration:$timestamps{ $device}{ \"duration\" } duration_mins:$timestamps{ $device}{ \"duration_mins\" }\n");

}

$timestamps{ "end" } = chomp(`date --utc +\%s`);
print("\$timestamps{ \"end\" }:$timestamps{ \"end\" }\n");

$timestamps{ "duration" } = $timestamps{ "end" } - $timestamps{ start };
$timestamps{ "duration_mins" } = $timestamps{ "duration" } / 60;

print("## duration:$timestamps{ \"duration\" } duration_mins:$timestamps{ \"duration_mins\" }\n");

sub ansible_command{

	my %outputs = %{$_[0]};
	my %timestamps = %{$_[1]};

	my $device = $_[2];
	my $qdisc = $_[3];
	my $step = $_[4];
	my $command = $_[5];

	print("## Step:$step\n");
	$outputs{ $device}{ $qdisc }{ $step } = `$command`;
	$timestamps{ $device }{ $qdisc }{ $step } = chomp(`date --utc +\%s`);
	foreach (@{ $outputs{ $device }{ $qdisc }{ $step } }) {
		print("\t$_");
	}
}

sub gather_details_for_tests_from_device {

	my %outputs=%{$_[0]};
	my %timestamps=%{$_[1]};

	my $device=$_[2];
	my $qdisc=$_[3];
	my $stage=$_[4]; # stage is "before" or "after"
	my $timestamp=$_[5];

	my $dir = "test_device_$device\_qdisc_$qdisc\_$stage/";
	print("## dir:$dir\n");

	my $step = "ansible_gather_stats_before";
	print("## Step:$step\n");
	$outputs{ $device}{ $qdisc }{ $step } = `ansible $device -i ./device_info/ansible_hosts --become -m script -a ./gather_details_for_tests.bash /tmp/$dir`;
	$timestamps{ $device }{ $qdisc }{ $step } = chomp(`date --utc +\%s`);

	print("## mkdir --parents /tmp/output_$timestamp/$device/$qdisc/$stage\n");
	`mkdir --parents /tmp/output_$timestamp/$device/$qdisc/$stage`;

	$step = "rsync_stats_before";
	print("## Step:$step\n");
	# MUST USE --trust-sender!!!  !!!!
	$outputs{ $device }{ $qdisc }{ $step } = `rsync -avz --trust-sender $device:/tmp/$dir /tmp/output_$timestamp/$device/$qdisc/$stage`;
	$timestamps{ $device }{ $qdisc }{ $step } = chomp(`date --utc +\%s`);
	foreach (@{ $outputs{ $step } }) {
		print("\t$_");
	}
}

sub gather_details_for_tests_from_laptops {

	my %outputs=$_[0];
	my %timestamps=$_[1];

	my $device=$_[2];
	my $qdisc=$_[3];
	my $stage=$_[4]; # stage is "before" or "after"
	my $timestamp=$_[5];

	my @laptops=qw(3rd ryzen);
	foreach (@laptops) {
		my $laptop = $_;

		my $dir = "test_laptop_${laptop}_device_${device}_qdisc_${qdisc}_${stage}/";
		print("## dir:$dir\n");

		my $step = "ansible_gather_laptop_stats_before";
		print("## Step:$step\n");
		$outputs{ $device }{ $qdisc }{ $step } = `ansible $laptop -i ./device_info/ansible_hosts --become -m script -a ./gather_details_for_tests.bash /tmp/$dir`;
		$timestamps{ $device }{ $qdisc }{ $step } = chomp(`date --utc +\%s`);

		print("## mkdir --parents /tmp/output_$timestamp/$device/$qdisc/$stage\n");
		`mkdir --parents /tmp/output_$timestamp/$device/$qdisc/$stage`;

		$step = "rsync_laptop_stats_before";
		print("## Step:$step\n");
		# MUST USE --trust-sender!!!
		$outputs{ $device }{ $qdisc }{ $step } = `rsync -avz --trust-sender $laptop:/tmp/$dir /tmp/output_$timestamp/$device/$qdisc/$stage`;
		$timestamps{ $device }{ $qdisc }{ $step } = chomp(`date --utc +\%s`);
		foreach (@{ $outputs{ $device }{ $qdisc }{ $step } }) {
			print("\t$_");
		}
	}
}