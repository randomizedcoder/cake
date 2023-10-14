package qdisc_tester

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"log"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

const (
	subnetOctectA = 172
	subnetOctectB = 16
	serverOctectD = 10
	vlanStart     = 100
	vlanAddition  = 50

	scriptConfigDirCst  = "/script_configuration/"
	configDevicesDirCst = "/configure_device_scripts/"
	deviceInfoDirCst    = "/device_info/"
	ansibleDirCst       = "/ansible/"
	ansibleHostFileCst  = "ansible_hosts"

	base10      = 10
	FileModeCst = 0744

	ansibleTimeoutCst       = 1 * time.Minute
	ansibleRebootTimeoutCst = 90 * time.Second
	icmpPingTimeoutCst      = 15 * time.Second
	rsyncTimeoutCst         = 30 * time.Second
	snmpwalkTimeoutCst      = 3 * time.Second

	routerHostnameCst = "3750x"

	pingZeroLossCst = "0% packet loss"
	rsyncSuccessCst = "speedup is"

	//remoteMetadataHostnameCst = "ryzen"

	// prom consts
	quantileError    = 0.05
	summaryVecMaxAge = 5 * time.Minute
)

var (
	pC = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Subsystem: "counters",
			Name:      "qdisc_tester",
			Help:      "qdisc tester counters",
		},
		[]string{"function", "device", "qdisc", "type"},
	)

	pH = promauto.NewSummaryVec(
		prometheus.SummaryOpts{
			Subsystem: "histrograms",
			Name:      "qdisc_tester",
			Help:      "qdisc_tester histograms",
			Objectives: map[float64]float64{
				0.1:  quantileError,
				0.5:  quantileError,
				0.99: quantileError,
			},
			MaxAge: summaryVecMaxAge,
		},
		[]string{"function", "device", "qdisc", "type"},
	)
)

type deviceTest struct {
	device     string
	qdisc      string
	testClient string
	phase      string
	step       string

	stdout *bytes.Buffer
	stderr *bytes.Buffer

	startTime time.Time
	endTime   time.Time
	duration  time.Duration

	success bool
}

type FileNames struct {
	Devices     string
	Qdiscs      string
	Laptops     string
	IntMap      string
	IntSNMPMap  string
	IntCounters string
}

type IperfConfig struct {
	IperfIntervalSeconds   int
	IperfTimeSeconds       int
	IperfTimeBufferSeconds int
	IperfParallel          int
}

type QdiscTester interface {
	RunTests()

	testDeviceQdisc(di int, device string, qi int, qdisc string)

	executeAnsible(device string, qdisc string, phase string, step string, command string, timeout time.Duration, containsSuccess string) (dt deviceTest)
	icmpPing(device string, qdisc string, phase string, step string, timeout time.Duration, namespace string, ip string) (dt deviceTest)
	gatherDetailsFromTestDevice(device string, qdisc string, phase string, step string) (dt deviceTest)

	getFullCommand(c string) (fullCommand string)
	readFileToSlice(filename string) (lines []string)

	showOutput()
}

// type device string
// type qdisc string
// type testClient string
// type phase string
// type step string

type QdiscTest struct {
	debugLevel  int
	fastForward string
	foundStep   bool
	reboot      bool

	logger *zap.Logger
	sugar  *zap.SugaredLogger

	cakePath    string
	devices     []string
	qdiscs      []string
	laptops     []string
	intCounters []string

	testsComplete int

	instance   string
	fileMode   os.FileMode
	outputPath string

	deviceToSwitchInterface map[string]string
	interfaceToSNMPIndex    map[string]string

	ansibleCommandPrefix         string
	ansiblePlaybookCommandPrefix string

	fullPaths map[string]string
	// device, qdisc, testClient, phase, step
	deviceTests map[string]map[string]map[string]map[string]map[string]deviceTest
	//deviceTests map[device]map[qdisc]map[testClient]map[phase]map[step]deviceTest

	iperfConf IperfConfig
}

// NewQdiscTest is a constructor for the qdisc tests
func NewQdiscTest(cakePath string, fns FileNames, ic IperfConfig, outputPath string, reboot bool, debugLevel int, ff string) *QdiscTest {

	q := new(QdiscTest)

	q.debugLevel = debugLevel
	q.fastForward = ff
	if len(q.fastForward) == 0 {
		q.foundStep = true
	}
	q.reboot = reboot

	t := time.Now()
	q.instance = fmt.Sprintf("%d-%02d-%02dT%02d:%02d:%02d",
		t.Year(), t.Month(), t.Day(),
		t.Hour(), t.Minute(), t.Second())

	q.fileMode = os.FileMode(FileModeCst)

	q.outputPath = outputPath + q.instance
	if err := os.MkdirAll(q.outputPath, q.fileMode); err != nil {
		log.Fatal(err)
	}

	logfile, err := os.Create(q.outputPath + "/log.json")
	if err != nil {
		log.Fatal(err)
	}

	// config := zap.Config{
	// 	Level:            zap.NewAtomicLevelAt(zapcore.InfoLevel),
	// 	Development:      true,
	// 	Encoding:         "json",
	// 	EncoderConfig:    zap.NewProductionEncoderConfig(),
	// 	OutputPaths:      []string{"stdout"},
	// 	ErrorOutputPaths: []string{"stderr"},
	// }

	// l, err := config.Build()
	// if err != nil {
	// 	log.Fatal("config.Build(config) error", err)
	// }
	// q.logger = l

	encoderConfig := zapcore.EncoderConfig{
		TimeKey:       "timestamp",
		LevelKey:      "level",
		NameKey:       "logger",
		CallerKey:     "caller",
		MessageKey:    "message",
		StacktraceKey: "stacktrace",
		LineEnding:    zapcore.DefaultLineEnding,
		EncodeLevel:   zapcore.CapitalLevelEncoder, // Capitalize the log level names
		//EncodeTime:     zapcore.ISO8601TimeEncoder,     // ISO8601 UTC timestamp format
		EncodeTime:     zapcore.RFC3339TimeEncoder,
		EncodeDuration: zapcore.SecondsDurationEncoder, // Duration in seconds
		EncodeCaller:   zapcore.ShortCallerEncoder,     // Short caller (file and line)
	}

	core := zapcore.NewCore(
		zapcore.NewJSONEncoder(encoderConfig),
		zapcore.NewMultiWriteSyncer(
			zapcore.AddSync(os.Stdout),
			zapcore.AddSync(logfile),
		),
		zap.InfoLevel,
	)

	q.logger = zap.New(core)

	//q.logger = zap.Must(zap.NewProduction()).WithOptions(zap.AddCaller())

	//defer dqt.Logger.Sync()
	q.sugar = q.logger.Sugar()

	q.cakePath = cakePath
	sp := cakePath + scriptConfigDirCst
	q.devices = q.readFileToSlice(sp+fns.Devices, true)
	q.qdiscs = q.readFileToSlice(sp+fns.Qdiscs, true)
	// temp for testing
	//q.qdiscs = []string{"noqueue", "pfifo_fast"}
	q.laptops = q.readFileToSlice(sp+fns.Laptops, true)
	// Add random shuffle here?

	if q.debugLevel > 10 {
		q.sugar.Info("q.devices:%s", q.devices)
		q.sugar.Info("q.qdiscs:%s", q.qdiscs)
		q.sugar.Info("q.laptops:%s", q.laptops)
	}

	q.deviceToSwitchInterface = q.fileToMap(sp + fns.IntMap)
	if q.debugLevel > 100 {
		for k, v := range q.deviceToSwitchInterface {
			q.sugar.Infof("q.deviceToSwitchInterface k:%s v:%s", k, v)
		}
	}

	q.interfaceToSNMPIndex = q.fileToMap(sp + fns.IntSNMPMap)
	if q.debugLevel > 100 {
		for k, v := range q.interfaceToSNMPIndex {
			q.sugar.Infof("q.interfaceToSNMPIndex k:%s v:%s", k, v)
		}
	}

	q.intCounters = q.readFileToSlice(sp+fns.IntCounters, false)

	// ansible $device -i /home/das/Downloads/cake/ansible/ansible_hosts
	q.ansibleCommandPrefix = "ansible $device -i " + q.cakePath + ansibleDirCst + ansibleHostFileCst
	// ansible $device -i /home/das/Downloads/cake/ansible/ansible_hosts /home/das/Downloads/cake/ansible/
	q.ansiblePlaybookCommandPrefix = "ansible-playbook -i " + q.cakePath + ansibleDirCst + ansibleHostFileCst + " " + q.cakePath + ansibleDirCst
	if q.debugLevel > 100 {
		q.sugar.Info("q.ansibleCommandPrefix:", q.ansibleCommandPrefix)
		q.sugar.Info("q.ansiblePlaybookCommandPrefix:", q.ansiblePlaybookCommandPrefix)
	}

	q.fullPaths = make(map[string]string)
	// device, qdisc, testClient, phase, step
	q.deviceTests = make(map[string]map[string]map[string]map[string]map[string]deviceTest)
	//q.deviceTests = make(map[device]map[qdisc]map[testClient]map[phase]map[step]deviceTest)

	q.iperfConf = ic

	return q
}

func (q *QdiscTest) RunTests() {

	defer func() {
		err := q.logger.Sync()
		if err != nil {
			log.Fatal("Logger.Sync error", err)
		}
	}()

	for di, device := range q.devices {

		q.sugar.Infow("device", "di", di, "device", device)
		q.deviceTests[device] = make(map[string]map[string]map[string]map[string]deviceTest)
		q.makeOutputDir(device)

		pC.WithLabelValues("testDeviceQdisc", device, "", "counter").Inc()

		for qi, qdisc := range q.qdiscs {

			q.sugar.Infow("qdisc", "qi", qi, "qdisc", qdisc)
			q.deviceTests[device][qdisc] = make(map[string]map[string]map[string]deviceTest)
			q.makeOutputDir(device, qdisc)

			pC.WithLabelValues("testDeviceQdisc", device, qdisc, "counter").Inc()

			// Flent doesn't work on ubuntu LTS because of a fping issue: https://github.com/tohojo/flent/issues/232
			//testClients := []string{"iperf", "flent"} //
			testClients := []string{"iperf"}
			for tci, testClient := range testClients {

				q.sugar.Infow("testClient", "tci", tci, "testClient", testClient)
				q.deviceTests[device][qdisc][testClient] = make(map[string]map[string]deviceTest)
				q.makeOutputDir(device, qdisc, testClient)

				q.testDeviceQdisc(di, device, qi, qdisc, testClient)

				q.testCompleted()
			}

		}
	}

	q.showOutput()

	q.sugar.Info("That's all Folks!")
}

func (q *QdiscTest) testDeviceQdisc(di int, device string, qi int, qdisc string, testClient string) {
	var (
		phase string
		step  string
		stepI int
	)

	ni := ((di + 1) * vlanStart) + (qi + 1)
	namespace := strconv.FormatInt(int64(ni), base10)
	//vlan := namespace

	octetA := subnetOctectA
	octetB := subnetOctectB + (di + 1)
	octetC := qi + 1 + vlanAddition
	octetD := serverOctectD
	ip := strconv.FormatInt(int64(octetA), base10) + "." +
		strconv.FormatInt(int64(octetB), base10) + "." +
		strconv.FormatInt(int64(octetC), base10) + "." +
		strconv.FormatInt(int64(octetD), base10)

	q.sugar.Info("######################################################")
	q.sugar.Info("######################################################")
	q.sugar.Infow(
		"testDeviceQdisc",
		"device", device,
		"qdisc", qdisc,
		"testClient", testClient,
		"namespace", namespace,
		//"vlan", vlan,
		"ip", ip,
	)

	// device, qdisc, testClient, phase, step

	//-------------------------------------------------------------------------
	phase = "before_test"
	q.makeOutputDir(device, qdisc, testClient, phase)
	q.deviceTests[device][qdisc][testClient][phase] = make(map[string]deviceTest)

	//------------
	stepI, step = q.newStep(device, qdisc, testClient, phase, stepI, "ansible_ping_before_reboot")
	// das@t:~/Downloads/cake$ ansible pi4 -i ./ansible/ansible_hosts -m ping
	// pi4 | SUCCESS => {
	// 	"changed": false,
	// 	"ping": "pong"
	// }
	if q.doStep(step) {
		q.deviceTests[device][qdisc][testClient][phase][step] = q.executeAnsible(device, qdisc, testClient, phase, step, q.ansibleCommandPrefix+" -m ping", ansibleTimeoutCst, "SUCCESS")
		q.writeStepDetails(device, qdisc, testClient, phase, step)
	}

	if q.reboot {
		stepI, step = q.newStep(device, qdisc, testClient, phase, stepI, "ansible_reboot")
		// das@t:~/Downloads/cake$ ansible pi4 -i ./ansible/ansible_hosts -m reboot --become
		// pi4 | CHANGED => {
		//     "changed": true,
		//     "elapsed": 63,
		//     "rebooted": true
		// }
		if q.doStep(step) {
			q.deviceTests[device][qdisc][testClient][phase][step] = q.executeAnsible(device, qdisc, testClient, phase, step, q.ansibleCommandPrefix+" -m reboot --become", ansibleTimeoutCst, "CHANGED")
			q.writeStepDetails(device, qdisc, testClient, phase, step)
		}
	} else {
		q.sugar.Info("sleep for 1 second, instead of reboot")
		time.Sleep(1 * time.Second)
	}

	//------------
	stepI, step = q.newStep(device, qdisc, testClient, phase, stepI, "ansible_ping_after_reboot")
	if q.doStep(step) {
		q.deviceTests[device][qdisc][testClient][phase][step] = q.executeAnsible(device, qdisc, testClient, phase, step, q.ansibleCommandPrefix+" -m ping", ansibleRebootTimeoutCst, "SUCCESS")
		q.writeStepDetails(device, qdisc, testClient, phase, step)
	}

	//------------
	stepI, step = q.newStep(device, qdisc, testClient, phase, stepI, "configure_qdiscs")
	if q.doStep(step) {
		q.deviceTests[device][qdisc][testClient][phase][step] = q.executeAnsible(device, qdisc, testClient, phase, step, q.ansibleCommandPrefix+" -m script -a "+q.cakePath+configDevicesDirCst+"qdisc.bash", ansibleTimeoutCst, "CHANGED")
		q.writeStepDetails(device, qdisc, testClient, phase, step)
	}

	//------------
	stepI, step = q.newStep(device, qdisc, testClient, phase, stepI, "icmp_ping")
	if q.doStep(step) {
		q.deviceTests[device][qdisc][testClient][phase][step] = q.icmpPing(device, qdisc, testClient, phase, step, icmpPingTimeoutCst, namespace, ip)
		if q.debugLevel > 10 {
			q.sugar.Info("###icmpPing:", q.deviceTests[device][qdisc][testClient][phase][step])
			log.Printf("%v", q.deviceTests[device][qdisc][testClient][phase][step])
		}
		q.writeStepDetails(device, qdisc, testClient, phase, step)
	}

	//------------
	stepI, step = q.newStep(device, qdisc, testClient, phase, stepI, "gather_details")
	if q.doStep(step) {
		q.deviceTests[device][qdisc][testClient][phase][step] = q.gatherAndRsyncDetailsFromTestDevice(device, qdisc, testClient, phase, step)
		q.writeStepDetails(device, qdisc, testClient, phase, step)
	}

	//------------
	stepI, step = q.newStep(device, qdisc, testClient, phase, stepI, "clear_device_interface_counters")
	if q.doStep(step) {
		deviceSwitchInterface, ok := q.deviceToSwitchInterface[device]
		if !ok {
			q.sugar.Fatal("can't find clear counters interface for device:", device)
		}
		// das@t:~/Downloads/cake/ansible$ make clear_counters_interface
		// ansible-playbook -i ./ansible_hosts ansible_cisco_clear_counters_interface.yml --extra-vars "interface=gi1/0/1"

		// PLAY [Cisco clear counters interface] *************************************************************************************************************************************************************************************************

		// TASK [clear counters interface] *******************************************************************************************************************************************************************************************************
		// ok: [3750x]

		// PLAY RECAP ****************************************************************************************************************************************************************************************************************************
		// 3750x                      : ok=1    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
		q.deviceTests[device][qdisc][testClient][phase][step] = q.executeAnsible(device, qdisc, testClient, phase, step, q.ansiblePlaybookCommandPrefix+"ansible_cisco_clear_counters_interface.yml --extra-vars targets=3750x --extra-vars interface="+deviceSwitchInterface, ansibleTimeoutCst, "ok=1")
		q.writeStepDetails(device, qdisc, testClient, phase, step)
	}

	//------------
	for _, laptop := range q.laptops {
		stepI, step = q.newStep(device, qdisc, testClient, phase, stepI, "clear_laptop_"+laptop+"_interface_counters")
		if q.doStep(step) {
			laptopSwitchInterface, ok := q.deviceToSwitchInterface[laptop]
			if !ok {
				q.sugar.Fatal("can't find clear counters interface for laptop:", laptop)
			}
			q.deviceTests[device][qdisc][testClient][phase][step] = q.executeAnsible(device, qdisc, testClient, phase, step, q.ansiblePlaybookCommandPrefix+"ansible_cisco_clear_counters_interface.yml --extra-vars targets=3750x --extra-vars interface="+laptopSwitchInterface, ansibleTimeoutCst, "ok=1")
			q.writeStepDetails(device, qdisc, testClient, phase, step)
		}
	}

	//------------
	stepI, step = q.newStep(device, qdisc, testClient, phase, stepI, "get_snmp_interface_counters")
	if q.doStep(step) {
		deviceSwitchInterface, ok := q.deviceToSwitchInterface[device]
		if !ok {
			q.sugar.Fatal("can't find interface for device snmp query:", device)
		}
		q.deviceTests[device][qdisc][testClient][phase][step] = q.getSNMPInterfaceCounters(device, qdisc, testClient, phase, step, deviceSwitchInterface)
		q.writeStepDetails(device, qdisc, testClient, phase, step)
	}

	//------------
	for _, laptop := range q.laptops {
		stepI, step = q.newStep(device, qdisc, testClient, phase, stepI, "get_snmp_interface_counters_laptop_"+laptop)
		if q.doStep(step) {
			laptopSwitchInterface, ok := q.deviceToSwitchInterface[laptop]
			if !ok {
				q.sugar.Fatal("can't find interface for laptop snmp query:", laptop)
			}
			q.deviceTests[device][qdisc][testClient][phase][step] = q.getSNMPInterfaceCounters(device, qdisc, testClient, phase, step, laptopSwitchInterface)
			q.writeStepDetails(device, qdisc, testClient, phase, step)
		}
	}

	//------------
	stepI, step = q.newStep(device, qdisc, testClient, phase, stepI, "show_interface_counters")
	// das@t:~/Downloads/cake/ansible$ make show_interface_capture
	// ansible-playbook -i ./ansible_hosts ansible_cisco_show_interface_capture.yml --extra-vars targets=3750x --extra-vars interface=gi1/0/1 --extra-vars destfile=c3750x_show_int_gi_1_0_1

	// PLAY [show interface capture] *********************************************************************************************************************************************************************************************************

	// TASK [show interface] *****************************************************************************************************************************************************************************************************************
	// ok: [3750x]

	// TASK [save output to local directory] *************************************************************************************************************************************************************************************************
	// changed: [3750x]

	// PLAY RECAP ****************************************************************************************************************************************************************************************************************************
	// 3750x                      : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0

	// #ansible-playbook -i ./ansible_hosts ansible_cisco_show_interface_capture.yml --extra-vars "interface=NT destfile=ESTFILE"
	if q.doStep(step) {
		deviceSwitchInterface, ok := q.deviceToSwitchInterface[device]
		if !ok {
			q.sugar.Fatal("can't find interface for device show interface counters query:", device)
		}
		dir := q.stepDir(device, qdisc, testClient, phase, step)
		q.deviceTests[device][qdisc][testClient][phase][step] = q.executeAnsible(device, qdisc, testClient, phase, step, q.ansiblePlaybookCommandPrefix+"ansible_cisco_show_interface_capture.yml --extra-vars targets=3750x --extra-vars destfile="+dir+"/show_interface_"+strings.ReplaceAll(deviceSwitchInterface, "/", "_")+" --extra-vars interface="+deviceSwitchInterface, ansibleTimeoutCst, "ok=2")
		q.writeStepDetails(device, qdisc, testClient, phase, step)
	}

	//------------
	for _, laptop := range q.laptops {
		if q.doStep(step) {
			stepI, step = q.newStep(device, qdisc, testClient, phase, stepI, "show_interface_counters_laptop_"+laptop)
			laptopSwitchInterface, ok := q.deviceToSwitchInterface[laptop]
			if !ok {
				q.sugar.Fatal("can't find interface for laptop show interface:", laptop)
			}
			dir := q.stepDir(device, qdisc, testClient, phase, step)
			q.deviceTests[device][qdisc][testClient][phase][step] = q.executeAnsible(device, qdisc, testClient, phase, step, q.ansiblePlaybookCommandPrefix+"ansible_cisco_show_interface_capture.yml --extra-vars targets=3750x --extra-vars destfile="+dir+"/show_interface_"+laptop+"_"+strings.ReplaceAll(laptopSwitchInterface, "/", "_")+" --extra-vars interface="+laptopSwitchInterface, ansibleTimeoutCst, "ok=2")
			q.writeStepDetails(device, qdisc, testClient, phase, step)
		}
	}

	//-------------------------------------------------------------------------
	phase = "test"
	q.makeOutputDir(device, qdisc, testClient, phase)
	q.deviceTests[device][qdisc][testClient][phase] = make(map[string]deviceTest)

	switch testClient {

	case "iperf":

		stepI, step = q.newStep(device, qdisc, testClient, phase, stepI, testClient)
		if q.doStep(step) {
			q.deviceTests[device][qdisc][testClient][phase][step] = q.executeIperf(device, qdisc, testClient, phase, step, namespace, ip)
			q.writeStepDetails(device, qdisc, testClient, phase, step)
		}

	case "flent":

		stepI, step = q.newStep(device, qdisc, testClient, phase, stepI, testClient)
		if q.doStep(step) {
			q.deviceTests[device][qdisc][testClient][phase][step] = q.executeFlent(device, qdisc, testClient, phase, step, namespace, ip)
			q.writeStepDetails(device, qdisc, testClient, phase, step)
		}

	default:
		q.sugar.Info("oh dear this shouldn't happen")

	}

	//-------------------------------------------------------------------------
	phase = "after_test"
	q.makeOutputDir(device, qdisc, testClient, phase)
	q.deviceTests[device][qdisc][testClient][phase] = make(map[string]deviceTest)

	//------------
	stepI, step = q.newStep(device, qdisc, testClient, phase, stepI, "icmp_ping")
	q.deviceTests[device][qdisc][testClient][phase][step] = q.icmpPing(device, qdisc, testClient, phase, step, icmpPingTimeoutCst, namespace, ip)
	if q.debugLevel > 10 {
		q.sugar.Info("###icmpPing:", q.deviceTests[device][qdisc][testClient][phase][step])
		log.Printf("%v", q.deviceTests[device][qdisc][testClient][phase][step])
	}
	q.writeStepDetails(device, qdisc, testClient, phase, step)

	//------------
	stepI, step = q.newStep(device, qdisc, testClient, phase, stepI, "gather_details")
	q.deviceTests[device][qdisc][testClient][phase][step] = q.gatherAndRsyncDetailsFromTestDevice(device, qdisc, testClient, phase, step)
	q.writeStepDetails(device, qdisc, testClient, phase, step)

	//------------
	stepI, step = q.newStep(device, qdisc, testClient, phase, stepI, "get_snmp_interface_counters")
	deviceSwitchInterface, ok := q.deviceToSwitchInterface[device]
	if !ok {
		q.sugar.Fatal("can't find interface for device snmp query:", device)
	}
	q.deviceTests[device][qdisc][testClient][phase][step] = q.getSNMPInterfaceCounters(device, qdisc, testClient, phase, step, deviceSwitchInterface)
	q.writeStepDetails(device, qdisc, testClient, phase, step)

	//------------
	for _, laptop := range q.laptops {
		stepI, step = q.newStep(device, qdisc, testClient, phase, stepI, "get_snmp_interface_counters_laptop_"+laptop)
		laptopSwitchInterface, ok := q.deviceToSwitchInterface[laptop]
		if !ok {
			q.sugar.Fatal("can't find interface for laptop snmp query:", laptop)
		}
		q.deviceTests[device][qdisc][testClient][phase][step] = q.getSNMPInterfaceCounters(device, qdisc, testClient, phase, step, laptopSwitchInterface)
		q.writeStepDetails(device, qdisc, testClient, phase, step)
	}

	//------------
	stepI, step = q.newStep(device, qdisc, testClient, phase, stepI, "show_interface_counters")
	// das@t:~/Downloads/cake/ansible$ make show_interface_capture
	// ansible-playbook -i ./ansible_hosts ansible_cisco_show_interface_capture.yml --extra-vars targets=3750x --extra-vars interface=gi1/0/1 --extra-vars destfile=c3750x_show_int_gi_1_0_1

	// PLAY [show interface capture] *********************************************************************************************************************************************************************************************************

	// TASK [show interface] *****************************************************************************************************************************************************************************************************************
	// ok: [3750x]

	// TASK [save output to local directory] *************************************************************************************************************************************************************************************************
	// changed: [3750x]

	// PLAY RECAP ****************************************************************************************************************************************************************************************************************************
	// 3750x                      : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0

	// #ansible-playbook -i ./ansible_hosts ansible_cisco_show_interface_capture.yml --extra-vars "interface=NT destfile=ESTFILE"
	dir := q.stepDir(device, qdisc, testClient, phase, step)
	q.deviceTests[device][qdisc][testClient][phase][step] = q.executeAnsible(device, qdisc, testClient, phase, step, q.ansiblePlaybookCommandPrefix+"ansible_cisco_show_interface_capture.yml --extra-vars targets=3750x --extra-vars destfile="+dir+"/show_interface_"+strings.ReplaceAll(deviceSwitchInterface, "/", "_")+" --extra-vars interface="+deviceSwitchInterface, ansibleTimeoutCst, "ok=2")
	q.writeStepDetails(device, qdisc, testClient, phase, step)

	//------------
	for _, laptop := range q.laptops {
		stepI, step = q.newStep(device, qdisc, testClient, phase, stepI, "show_interface_counters_laptop_"+laptop)
		laptopSwitchInterface, ok := q.deviceToSwitchInterface[laptop]
		if !ok {
			q.sugar.Fatal("can't find interface for laptop show interface:", laptop)
		}
		dir := q.stepDir(device, qdisc, testClient, phase, step)
		q.deviceTests[device][qdisc][testClient][phase][step] = q.executeAnsible(device, qdisc, testClient, phase, step, q.ansiblePlaybookCommandPrefix+"ansible_cisco_show_interface_capture.yml --extra-vars targets=3750x --extra-vars destfile="+dir+"/show_interface_"+laptop+"_"+strings.ReplaceAll(laptopSwitchInterface, "/", "_")+" --extra-vars interface="+laptopSwitchInterface, ansibleTimeoutCst, "ok=2")
		q.writeStepDetails(device, qdisc, testClient, phase, step)
	}

}

func (q *QdiscTest) executeIperf(device string, qdisc string, testClient string, phase string, step string, namespace string, ip string) (dt deviceTest) {

	defer pH.WithLabelValues("executeIperf", device, qdisc, "complete").Observe(time.Since(dt.startTime).Seconds())
	pC.WithLabelValues("executeIperf", device, qdisc, "counter").Inc()

	q.sugar.Infow("executeIperf", "device", device, "qdisc", qdisc, "testClient", testClient, "phase", phase, "step", step)
	dt.device = device
	dt.qdisc = qdisc
	dt.testClient = testClient
	dt.phase = phase
	dt.step = step

	dt.startTime = time.Now()

	dt.stdout = new(bytes.Buffer)
	dt.stderr = new(bytes.Buffer)

	sudoFullCommand := q.getFullCommand("sudo")
	ipFullCommand := q.getFullCommand("ip")
	iperfFullCommand := q.getFullCommand("iperf")
	if q.debugLevel > 10 {
		q.sugar.Infow("FullCommands:",
			"sudoFullCommand", sudoFullCommand,
			"ipFullCommand", ipFullCommand,
			"iperfFullCommand", iperfFullCommand)
	}

	args := []string{
		ipFullCommand,
		"netns",
		"exec",
		"network" + namespace,
		iperfFullCommand,
		"--client", ip,
		"--interval", strconv.FormatInt(int64(q.iperfConf.IperfIntervalSeconds), base10),
		"--time", strconv.FormatInt(int64(q.iperfConf.IperfTimeSeconds), base10),
		"--parallel", strconv.FormatInt(int64(q.iperfConf.IperfParallel), base10),
		"--dualtest",
		"--enhanced",
		"--sum-only",
	}

	if q.debugLevel > 10 {
		q.sugar.Infow("command:", "args", args)
	}
	if q.debugLevel > 10 {
		commandString := sudoFullCommand
		for _, arg := range args {
			commandString += " " + arg
		}
		q.sugar.Infow("executeIperf:", "commandString", commandString)
	}

	ctx, cancel := context.WithTimeout(context.Background(), (time.Duration(q.iperfConf.IperfTimeSeconds)*time.Second)+(time.Duration(q.iperfConf.IperfTimeBufferSeconds)*time.Second))
	defer cancel()

	cmd := exec.CommandContext(ctx, sudoFullCommand, args...)
	cmd.Stdout = dt.stdout
	cmd.Stderr = dt.stderr

	q.sugar.Info("###################################")
	q.sugar.Infof("##### iperf device:%s qdisc:%s", device, qdisc)

	err := cmd.Run()
	if err != nil {
		q.sugar.Error("iperf", zap.Error(err))
	}

	// Fix me
	// if bytes.Contains(dt.stdout.Bytes(), []byte(rsyncSuccessCst)) {
	// 	dt.success = true
	// 	if q.debugLevel > 10 {
	// 		q.sugar.Info("success!")
	// 	}
	// }

	dt.endTime = time.Now()
	dt.duration = dt.endTime.Sub(dt.startTime)

	if q.debugLevel > 10 {
		q.sugar.Infow("executeIperf:", "dt.duration", dt.duration.String())
	}

	return dt

}

// ip netns exec network"${y}" \
// flent rrul \
// -p all_scaled \
// -l 600 \
// -H 172.16."${x}".10 \
// -t 172.16."${x}".10_"${devices[${i}]}" \
// -o "${devices[${i}]}".png
func (q *QdiscTest) executeFlent(device string, qdisc string, testClient string, phase string, step string, namespace string, ip string) (dt deviceTest) {

	defer pH.WithLabelValues("executeFlent", device, qdisc, "complete").Observe(time.Since(dt.startTime).Seconds())
	pC.WithLabelValues("executeFlent", device, qdisc, "counter").Inc()

	q.sugar.Infow("executeFlent", "device", device, "qdisc", qdisc, "testClient", testClient, "phase", phase, "step", step)
	dt.device = device
	dt.qdisc = qdisc
	dt.testClient = testClient
	dt.phase = phase
	dt.step = step

	dt.startTime = time.Now()

	dt.stdout = new(bytes.Buffer)
	dt.stderr = new(bytes.Buffer)

	sudoFullCommand := q.getFullCommand("sudo")
	ipFullCommand := q.getFullCommand("ip")
	flentFullCommand := q.getFullCommand("flent")
	if q.debugLevel > 10 {
		q.sugar.Infow("FullCommands:",
			"sudoFullCommand", sudoFullCommand,
			"ipFullCommand", ipFullCommand,
			"flentFullCommand", flentFullCommand)
	}

	args := []string{
		ipFullCommand,
		"netns",
		"exec",
		"network" + namespace,
		flentFullCommand,
		"rrul", // test name
		// Options
		"--output ", q.stepDir(device, qdisc, testClient, phase, step) + "/flent_" + device + "_" + qdisc + ".png",
		"--data-dir", q.stepDir(device, qdisc, testClient, phase, step) + "/",
		"--format", "summary", // default format
		"--plot", "all_scaled",
		"--title-extra", q.instance + "_" + device + "_" + qdisc,
		"--note", q.instance + "_" + device + "_" + qdisc,
		"--extended-metadata",
		//"--remote-metadata", remoteMetadataHostnameCst, // NOT doing this yet, because I'm not sure we can ssh from the namespace
		// Test config
		"--host", ip,
		"--length", strconv.FormatInt(int64(q.iperfConf.IperfTimeSeconds), base10),
		"--ipv4",
		"--socket-stats",
	}

	if q.debugLevel > 10 {
		q.sugar.Infow("command:", "args", args)
	}
	if q.debugLevel > 10 {
		commandString := sudoFullCommand
		for _, arg := range args {
			commandString += " " + arg
		}
		q.sugar.Infow("executeFlent:", "commandString", commandString)
	}

	ctx, cancel := context.WithTimeout(context.Background(), (time.Duration(q.iperfConf.IperfTimeSeconds)*time.Second)+(time.Duration(q.iperfConf.IperfTimeBufferSeconds)*time.Second))
	defer cancel()

	// sudo is REQUIRED to execute in the name space!!
	cmd := exec.CommandContext(ctx, sudoFullCommand, args...)
	cmd.Stdout = dt.stdout
	cmd.Stderr = dt.stderr

	q.sugar.Info("###################################")
	q.sugar.Infof("##### flent device:%s qdisc:%s", device, qdisc)

	err := cmd.Run()
	if err != nil {
		q.sugar.Error("flent", zap.Error(err))
	}

	// Fix me
	// if bytes.Contains(dt.stdout.Bytes(), []byte(rsyncSuccessCst)) {
	// 	dt.success = true
	// 	if q.debugLevel > 10 {
	// 		q.sugar.Info("success!")
	// 	}
	// }

	dt.endTime = time.Now()
	dt.duration = dt.endTime.Sub(dt.startTime)

	if q.debugLevel > 10 {
		q.sugar.Infow("executeFlent:", "dt.duration", dt.duration.String())
	}

	return dt

}

// gatherDetailsFromTestDevice run ansible directly, because of the need to pass the script name and the arguments as a
// single argument, which doesn't work in executeAnsible because of the string splitting happening
func (q *QdiscTest) gatherAndRsyncDetailsFromTestDevice(device string, qdisc string, testClient string, phase string, step string) (dt deviceTest) {

	defer pH.WithLabelValues("gatherAndRsyncDetailsFromTestDevice", device, qdisc, "complete").Observe(time.Since(dt.startTime).Seconds())
	pC.WithLabelValues("gatherAndRsyncDetailsFromTestDevice", device, qdisc, "counter").Inc()

	q.sugar.Infow("gatherDetailsFromTestDevice", "device", device, "qdisc", qdisc, "testClient", testClient, "phase", phase, "step", step)

	dir := "test_device_" + device + "_" + qdisc + "_" + phase + "_" + step + "/"
	if q.debugLevel > 10 {
		q.sugar.Info("dir:", dir)
	}

	dt = q.executeAnsible(device, qdisc, testClient, phase, step,
		q.ansibleCommandPrefix+" --become -m script -a "+q.cakePath+deviceInfoDirCst+"gather_details_for_tests.bash /tmp/"+dir, ansibleTimeoutCst, "CHANGED")

	rsyncFullCommand := q.getFullCommand("rsync")

	args := []string{
		"--archive",
		"--verbose",
		"--compress",
		"--trust-sender",
		device + ":/tmp/" + dir,
		q.stepDir(device, qdisc, testClient, phase, step) + "/" + dir,
	}
	if q.debugLevel > 10 {
		q.sugar.Infow("command:", "args", args)
	}

	ctx, cancel := context.WithTimeout(context.Background(), rsyncTimeoutCst)
	defer cancel()

	cmd := exec.CommandContext(ctx, rsyncFullCommand, args...)
	cmd.Stdout = dt.stdout
	cmd.Stderr = dt.stderr

	err := cmd.Run()
	if err != nil {
		q.sugar.Error("rsync", zap.Error(err))
	}

	if bytes.Contains(dt.stdout.Bytes(), []byte(rsyncSuccessCst)) {
		dt.success = true
		if q.debugLevel > 10 {
			q.sugar.Info("success!")
		}
	}

	dt.endTime = time.Now()
	dt.duration = dt.endTime.Sub(dt.startTime)

	return dt
}

// icmpPing runs a simple icmp ping command, capturing stdout+stderr, records timing information,
// and checks for 0% packet loss to singal success
func (q *QdiscTest) icmpPing(device string, qdisc string, testClient string, phase string, step string, timeout time.Duration, namespace string, ip string) (dt deviceTest) {

	defer pH.WithLabelValues("icmpPing", device, qdisc, "complete").Observe(time.Since(dt.startTime).Seconds())
	pC.WithLabelValues("icmpPing", device, qdisc, "counter").Inc()

	q.sugar.Infow("icmpPing", "device", device, "qdisc", qdisc, "testClient", testClient, "phase", phase, "step", step)
	dt.device = device
	dt.qdisc = qdisc
	dt.testClient = testClient
	dt.phase = phase
	dt.step = step

	dt.startTime = time.Now()

	dt.stdout = new(bytes.Buffer)
	dt.stderr = new(bytes.Buffer)

	sudoFullCommand := q.getFullCommand("sudo")
	ipFullCommand := q.getFullCommand("ip")
	pingFullCommand := q.getFullCommand("ping")
	if q.debugLevel > 10 {
		q.sugar.Infow("FullCommands:",
			"sudoFullCommand", sudoFullCommand,
			"ipFullCommand", ipFullCommand,
			"pingFullCommand", pingFullCommand)
	}

	args := []string{ipFullCommand, "netns", "exec", "network" + namespace, pingFullCommand, "-c", "3", "-W", "0.2", ip}
	if q.debugLevel > 10 {
		q.sugar.Infow("command:", "args", args)
	}

	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	cmd := exec.CommandContext(ctx, sudoFullCommand, args...)
	cmd.Stdout = dt.stdout
	cmd.Stderr = dt.stderr

	err := cmd.Run()
	if err != nil {
		q.sugar.Error("icmpPing", zap.Error(err))
	}

	if bytes.Contains(dt.stdout.Bytes(), []byte(pingZeroLossCst)) {
		dt.success = true
		if q.debugLevel > 10 {
			q.sugar.Info("success!")
		}
	}

	if q.debugLevel > 100 {
		q.sugar.Info("stdout:", "dt.stdout", dt.stdout)
		q.sugar.Info("stderr:", "dt.stderr", dt.stderr)
	}

	if q.debugLevel > 100 {
		scanner := bufio.NewScanner(dt.stdout)
		for scanner.Scan() {
			line := scanner.Text()
			q.sugar.Info("stdout:", "line", line)
		}
		if err := scanner.Err(); err != nil {
			q.sugar.Fatal(err)
		}
	}

	if q.debugLevel > 100 {
		dir := q.stepDir(device, qdisc, testClient, phase, step)
		q.sugar.Infow("stdout:", "dir", dir)

		if err := os.WriteFile(dir+"/stdout", q.deviceTests[device][qdisc][testClient][phase][step].stdout.Bytes(), FileModeCst); err != nil {
			q.sugar.Fatal(err)
		}
		if err := os.WriteFile(dir+"/stderr", q.deviceTests[device][qdisc][testClient][phase][step].stderr.Bytes(), FileModeCst); err != nil {
			q.sugar.Fatal(err)
		}
	}

	dt.endTime = time.Now()
	dt.duration = dt.endTime.Sub(dt.startTime)

	return dt
}

// executeAnsible runs an ansible command, capturing stdout+stderr, records timing information,
// and checks if a string is found in the stdout to singal success
func (q *QdiscTest) executeAnsible(device string, qdisc string, testClient string, phase string, step string, command string, timeout time.Duration, containsSuccess string) (dt deviceTest) {

	defer pH.WithLabelValues("executeAnsible", device, qdisc, "complete").Observe(time.Since(dt.startTime).Seconds())
	pC.WithLabelValues("executeAnsible", device, qdisc, "counter").Inc()

	q.sugar.Infow("executeAnsible", "device", device, "qdisc", qdisc, "testClient", testClient, "phase", phase, "step", step)
	dt.device = device
	dt.qdisc = qdisc
	dt.testClient = testClient
	dt.phase = phase
	dt.step = step

	dt.startTime = time.Now()

	dt.stdout = new(bytes.Buffer)
	dt.stderr = new(bytes.Buffer)

	parts := strings.Split(command, " ")
	for i, part := range parts {
		if strings.Contains(part, "$") {
			parts[i] = device
		}
	}

	// Little hack to merge the last two (2) arguments,
	// allowing an argument to be passed to "gather_details_for_tests"
	if strings.Contains(parts[len(parts)-2], "gather_details_for_tests") {
		parts[len(parts)-2] = parts[len(parts)-2] + " " + parts[len(parts)-1] // merge last 2 parts
		parts = parts[:len(parts)-1]                                          // chop off the last item
	}

	if q.debugLevel > 100 {
		q.sugar.Infow("executeAnsible:", "parts", parts)
	}
	if q.debugLevel > 10 {
		commandString := ""
		for _, part := range parts {
			commandString += " " + part
		}
		q.sugar.Infow("executeAnsible:", "commandString", commandString)
	}

	fullCommand := q.getFullCommand(parts[0])
	if q.debugLevel > 100 {
		q.sugar.Infow("executeAnsible:", "fullCommand", fullCommand)
	}

	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	cmd := exec.CommandContext(ctx, fullCommand, parts[1:]...)
	cmd.Stdout = dt.stdout
	cmd.Stderr = dt.stderr
	err := cmd.Run()
	if err != nil {
		q.sugar.Error("executeAnsible", zap.Error(err))
		q.sugar.Error("executeAnsible", "dt.stdout:", dt.stdout)
		q.sugar.Error("executeAnsible", "dt.stderr:", dt.stderr)
	}

	if bytes.Contains(dt.stdout.Bytes(), []byte(containsSuccess)) {
		dt.success = true
		if q.debugLevel > 10 {
			q.sugar.Info("success!")
		}
	}

	dt.endTime = time.Now()
	dt.duration = dt.endTime.Sub(dt.startTime)

	return dt
}

// getFullCommand does the expensive lookup to find the binary command
// in the path, and then caches this into the fullPaths map
// this way, we only do the expensive lookup once per invocation of this program
func (q *QdiscTest) getFullCommand(c string) (fullCommand string) {
	var ok bool
	fullCommand, ok = q.fullPaths[c]
	if !ok {
		var err error
		fullCommand, err = exec.LookPath(c)
		if err != nil {
			q.sugar.Fatal("can't find command", zap.Error(err))
		}
		q.fullPaths[c] = fullCommand
	}
	return fullCommand
}

// fileToMap reads a file with x2 columns ( device interface, interface to snmp index )
// and populates them into the deviceToSwitchInterface map
func (q *QdiscTest) fileToMap(filename string) (strStrMap map[string]string) {

	strStrMap = make(map[string]string)

	content, err := os.ReadFile(filename)
	if err != nil {
		q.sugar.Fatal("reading file error", zap.Error(err))
	}
	for _, line := range strings.Split(strings.ToLower(string(content)), "\n") {
		parts := strings.Fields(line)
		if len(parts) < 2 {
			q.sugar.Fatal("fileToMap failed to find x2 fields")
		}
		strStrMap[parts[0]] = parts[1]
	}

	return strStrMap
}

// readFileToSlice reads the file and converst to a slice of lines
func (q *QdiscTest) readFileToSlice(filename string, lower bool) (lines []string) {
	content, err := os.ReadFile(filename)
	if err != nil {
		q.sugar.Fatal("reading file error", zap.Error(err))
	}
	if lower {
		lines = strings.Split(strings.ToLower(string(content)), "\n")
	} else {
		lines = strings.Split(string(content), "\n")
	}
	return lines
}

// showOutput interates through deviceTests[device][qdisc][phase][step]
// and prints out duration and success
func (q *QdiscTest) showOutput() {
	for device := range q.deviceTests {
		for qdisc := range q.deviceTests[device] {
			for testClient := range q.deviceTests[device][qdisc] {
				for phase := range q.deviceTests[device][qdisc][testClient] {
					for step := range q.deviceTests[device][qdisc][testClient][phase] {
						q.sugar.Infow(
							"Test",
							"device", device,
							"qdisc", qdisc,
							"testClient", testClient,
							"phase", phase,
							"step", step,
							"duration", q.deviceTests[device][qdisc][testClient][phase][step].duration,
							"success", q.deviceTests[device][qdisc][testClient][phase][step].success,
						)
					}
				}
			}
		}
	}
}

// doStep allows steps to be skipped if fastFoward is set
// this function searchs for the step matching fastForward
// and then will cause execution of every following step
func (q *QdiscTest) doStep(stepName string) (doStep bool) {

	if q.foundStep {
		doStep = true
		return doStep
	}

	if q.fastForward == stepName {
		q.foundStep = true
		doStep = true
		return doStep
	}

	return doStep // false
}

// newStep is a tiny helper function to increment stepI, and then combine stepI + "_" + stepName
func (q *QdiscTest) newStep(device string, qdisc string, testClient string, phase string, i int, step string) (newI int, newStepName string) {

	pC.WithLabelValues("newStep", device, qdisc, "counter").Inc()

	newI = i + 1
	newStepName = strconv.FormatInt(int64(newI), base10) + "_" + step

	if q.doStep(step) {
		q.makeOutputDir(device, qdisc, testClient, phase, newStepName)
	}

	return newI, newStepName
}

func (q *QdiscTest) stepDir(dirs ...string) (dir string) {

	dir = q.outputPath
	for _, d := range dirs {
		dir += "/" + d
	}

	return dir
}

func (q *QdiscTest) makeOutputDir(dirs ...string) {

	dir := q.stepDir(dirs...)

	if err := os.Mkdir(dir, q.fileMode); err != nil {
		q.sugar.Fatal(err)
	}

}

func (q *QdiscTest) writeStepDetails(device string, qdisc string, testClient string, phase string, step string) {

	startTime := time.Now()
	defer pH.WithLabelValues("writeStepDetails", device, qdisc, "complete").Observe(time.Since(startTime).Seconds())
	pC.WithLabelValues("writeStepDetails", device, qdisc, "counter").Inc()

	dir := q.stepDir(device, qdisc, testClient, phase, step)

	if err := os.WriteFile(dir+"/stdout", q.deviceTests[device][qdisc][testClient][phase][step].stdout.Bytes(), FileModeCst); err != nil {
		log.Fatal(err)
	}
	// scanner := bufio.NewScanner(q.deviceTests[device][qdisc][testClient][phase][step].stdout)
	// for scanner.Scan() {
	// 	line := scanner.Text()
	// 	q.sugar.Info("stdout:", "line", line)
	// }

	if err := os.WriteFile(dir+"/stderr", q.deviceTests[device][qdisc][testClient][phase][step].stderr.Bytes(), FileModeCst); err != nil {
		log.Fatal(err)
	}

	if err := os.WriteFile(dir+"/starttime", []byte(q.deviceTests[device][qdisc][testClient][phase][step].startTime.Format(time.RFC3339)), FileModeCst); err != nil {
		log.Fatal(err)
	}

	if err := os.WriteFile(dir+"/endTime", []byte(q.deviceTests[device][qdisc][testClient][phase][step].endTime.Format(time.RFC3339)), FileModeCst); err != nil {
		log.Fatal(err)
	}

	if err := os.WriteFile(dir+"/duration", []byte(q.deviceTests[device][qdisc][testClient][phase][step].duration.String()), FileModeCst); err != nil {
		log.Fatal(err)
	}

	if q.deviceTests[device][qdisc][testClient][phase][step].success {
		if err := os.WriteFile(dir+"/success", []byte(""), 0666); err != nil {
			log.Fatal(err)
		}
	}

}

func (q *QdiscTest) getSNMPInterfaceCounters(device string, qdisc string, testClient string, phase string, step string, interfaceName string) (dt deviceTest) {

	defer pH.WithLabelValues("getSNMPInterfaceCounters", device, qdisc, "complete").Observe(time.Since(dt.startTime).Seconds())
	pC.WithLabelValues("getSNMPInterfaceCounters", device, qdisc, "counter").Inc()

	q.sugar.Infow("getSNMPInterfaceCounters", "device", device, "qdisc", qdisc, "phase", phase, "step", step, "interfaceName", interfaceName)
	dt.device = device
	dt.qdisc = qdisc
	dt.testClient = testClient
	dt.phase = phase
	dt.step = step

	dt.startTime = time.Now()

	dt.stdout = new(bytes.Buffer)
	dt.stderr = new(bytes.Buffer)

	snmpwalkFullCommand := q.getFullCommand("snmpwalk")
	if q.debugLevel > 10 {
		q.sugar.Infow("getSNMPInterfaceCounters:", "snmpwalkFullCommand", snmpwalkFullCommand)
	}

	// das@t:~/Downloads/cake/ansible$ snmpwalk -v2c -c public 172.16.40.64 ifMIB.ifMIBObjects.ifXTable.ifXEntry.ifHCInOctets.10101
	// IF-MIB::ifHCInOctets.10101 = Counter64: 0

	interfaceIndex, ok := q.interfaceToSNMPIndex[interfaceName]
	if !ok {
		q.sugar.Fatal("can't find interface index to gather snmp counters from for device:", device)
	}

	for _, counter := range q.intCounters {

		args := []string{
			"-v2c",
			"-c",
			"public",
			routerHostnameCst,
		}

		args = append(args, counter+"."+interfaceIndex)
		if q.debugLevel > 10 {
			q.sugar.Infof("getSNMPInterfaceCounters args:%v", args)
		}

		stdout := new(bytes.Buffer)
		stderr := new(bytes.Buffer)

		ctx, cancel := context.WithTimeout(context.Background(), snmpwalkTimeoutCst)
		defer cancel()

		cmd := exec.CommandContext(ctx, snmpwalkFullCommand, args...)
		cmd.Stdout = stdout
		cmd.Stderr = stderr
		err := cmd.Run()
		if err != nil {
			q.sugar.Error("executeAnsible", zap.Error(err))
			q.sugar.Error("executeAnsible", "stdout:", stdout)
			q.sugar.Error("executeAnsible", "stderr:", stderr)
		} else {
			dt.stdout.Write(stdout.Bytes())

			if q.debugLevel > 10 {
				q.sugar.Infof("getSNMPInterfaceCounters stdout:%v", stdout.String())
			}
		}

	}

	dt.endTime = time.Now()
	dt.duration = dt.endTime.Sub(dt.startTime)

	return dt
}

func (q *QdiscTest) testCompleted() {
	q.testsComplete++

	if err := os.WriteFile(q.outputPath+"/testsComplete", []byte(strconv.FormatInt(int64(q.testsComplete), base10)), FileModeCst); err != nil {
		log.Fatal(err)
	}
}
