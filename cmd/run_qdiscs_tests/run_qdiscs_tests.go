package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"qdisc_tester/pkg/qdisc_tester"
	"syscall"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

const (
	debugLevelCst = 11

	iperfIntervalSecondsCst   = 10
	iperfTimeSecondsCst       = 60
	iperfTimeBufferSecondsCst = 30
	iperfParallelCst          = 20

	flentLengthSecondsCst       = 60
	flentLengthBufferSecondsCst = 30

	signalChannelSize       = 10
	promListenCst           = ":9111"
	promPathCst             = "/metrics"
	promMaxRequestsInFlight = 10
	promEnableOpenMetrics   = true

	cakePathCst   = "/home/das/Downloads/cake"
	outputPathCst = "/tmp/qdisc/"
)

var (
	// Passed by "go build -ldflags" for the show version
	commit string
	date   string
)

func main() {

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	go initSignalHandler(cancel)

	version := flag.Bool("version", false, "version")

	// https://pkg.go.dev/net#Listen
	promListen := flag.String("promListen", promListenCst, "Prometheus http listening socket")
	promPath := flag.String("promPath", promPathCst, "Prometheus http path. Default = /metrics")
	// curl -s http://[::1]:9111/metrics 2>&1 | grep -v "#"
	// curl -s http://127.0.0.1:9111/metrics 2>&1 | grep -v "#"

	debugLevel := flag.Int("debugLevel", debugLevelCst, "nasty debugLevel")
	reboot := flag.Bool("reboot", false, "reboot devices before tests if this is set")
	shuffle := flag.Bool("shuffle", false, "shuffle devices and qdiscs")

	cakePath := flag.String("cakePath", cakePathCst, "file path containing the config files")
	devicesFilename := flag.String("devicesFilename", "devices.txt", "filename with the list of devices")
	qdiscsFilename := flag.String("qdiscsFilename", "qdiscs.txt", "filename with the list of qdiscs")
	laptopsFilename := flag.String("laptopsFilename", "laptops.txt", "filename with the list of laptops")
	intMapFilename := flag.String("intMapFilename", "device_to_interface_mapping.txt", "filename with the device to switch interface mapping")
	intSNMPMapFilename := flag.String("intSNMPMapFilename", "interface_to_snmp_index.txt", "filename with the switch interface to snmp index")
	intCountersFilename := flag.String("intCountersFilename", "interface_counters_to_collect.txt", "filename with the list of interface counters to collect")

	iperfIntervalSeconds := flag.Int("iperfIntervalSeconds", iperfIntervalSecondsCst, "iperfIntervalSeconds")
	iperfTimeSeconds := flag.Int("iperfTimeSeconds", iperfTimeSecondsCst, "iperfTimeSeconds")
	iperfTimeBufferSeconds := flag.Int("iperfTimeBufferSeconds", iperfTimeBufferSecondsCst, "iperfTimeBufferSeconds")
	iperfParallel := flag.Int("iperfParallel", iperfParallelCst, "iperfParallel")

	flentLengthSeconds := flag.Int("flentLengthSeconds", flentLengthSecondsCst, "flentLengthSeconds")
	flentLengthBufferSeconds := flag.Int("flentLengthBufferSeconds", flentLengthBufferSecondsCst, "flentLengthBufferSeconds")

	fastForward := flag.String("fastForward", "", "fastFoward to step.  This option allows you to specific the a named step, mostly to speed up the testing cycle")

	outputPath := flag.String("outputPath", outputPathCst, "Output path")
	// iperfIntervalSecs := flag.Int("iperfIntervalSecs", 30, "iperf reporting interval seconds")
	// iperfRunTimeSecs := flag.Int("iperfRunTimeSecs", 60, "iperf runtime seconds")
	// iperfParallel := flag.Int("iperfParallel", 60, "iperf parallel TCP streams")

	flag.Parse()

	if *version {
		fmt.Println("commit:", commit, "\tdate(UTC):", date)
		os.Exit(0)
	}

	go initPromHandler(ctx, *promPath, *promListen)

	fns := &qdisc_tester.FileNames{
		Devices:     *devicesFilename,
		Qdiscs:      *qdiscsFilename,
		Laptops:     *laptopsFilename,
		IntMap:      *intMapFilename,
		IntSNMPMap:  *intSNMPMapFilename,
		IntCounters: *intCountersFilename,
	}

	ic := &qdisc_tester.IperfConfig{
		IperfIntervalSeconds:   *iperfIntervalSeconds,
		IperfTimeSeconds:       *iperfTimeSeconds,
		IperfTimeBufferSeconds: *iperfTimeBufferSeconds,
		IperfParallel:          *iperfParallel,
	}

	fc := &qdisc_tester.FlentConfig{
		FlentLengthSeconds:       *flentLengthSeconds,
		FlentLengthBufferSeconds: *flentLengthBufferSeconds,
	}

	q := qdisc_tester.NewQdiscTest(*cakePath, *fns, *ic, *fc, *outputPath, *reboot, *shuffle, *debugLevel, *fastForward)

	q.RunTests()

	log.Println("main: That's all Folks!")

}

func initSignalHandler(cancel context.CancelFunc) {
	c := make(chan os.Signal, signalChannelSize)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)

	<-c
	log.Printf("Signal caught, closing application")
	cancel()
	os.Exit(0)
}

func initPromHandler(ctx context.Context, promPath string, promListen string) {
	// https: //pkg.go.dev/github.com/prometheus/client_golang/prometheus/promhttp?tab=doc#HandlerOpts
	http.Handle(promPath, promhttp.HandlerFor(
		prometheus.DefaultGatherer,
		promhttp.HandlerOpts{
			EnableOpenMetrics:   promEnableOpenMetrics,
			MaxRequestsInFlight: promMaxRequestsInFlight,
		},
	))
	go func() {
		err := http.ListenAndServe(promListen, nil)
		if err != nil {
			log.Fatal("prometheus error", err)
		}
	}()
}
