package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"
)

const (
	debugLevelCst = 11

	cakePathCst          = "/home/das/Downloads/cake"
	scriptConfigPathCst  = "/script_configuration/"
	configDevicesPathCst = "/configure_device_scripts/"

	base10 = 10
)

var (
	// Passed by "go build -ldflags" for the show version
	commit string
	date   string
)

func main() {

	version := flag.Bool("version", false, "version")

	debugLevel := flag.Int("debugLevel", debugLevelCst, "nasty debugLevel")

	cakePath := flag.String("cakePath", cakePathCst, "file path containing the config files")
	scriptConfigPath := flag.String("scriptConfigPath", scriptConfigPathCst, "sub path to the config files")
	configDevicesPath := flag.String("configDevicesPath", configDevicesPathCst, "sub path to the config files")
	devicesFilename := flag.String("devicesFilename", "devices.txt", "filename with the list of devices")

	flag.Parse()

	if *version {
		fmt.Println("commit:", commit, "\tdate(UTC):", date)
		os.Exit(0)
	}

	devices := readFileToSlice(*cakePath + *scriptConfigPath + *devicesFilename)

	// #!/usr/bin/bash

	// device=pi4
	// nic=eth0
	// device_count=1
	// bandwidth="950mbit"
	// #bandwidth="1gbit"
	// #"100mbit"

	// sudo ./cake_setup_routing_device.bash "${device}" "${nic}" "${device_count}" "${bandwidth}"

	for di, device := range devices {

		if *debugLevel > 10 {
			log.Println("di:", di, "device:", device)
		}

		filename := *cakePath + *configDevicesPath + "qdisc_" + device + ".bash"
		f, err := os.Create(filename)
		if err != nil {
			log.Fatal(err)
		}

		_, wErr := f.WriteString("#!/usr/bin/bash\n")
		if wErr != nil {
			log.Fatal(err)
		}

		bandwidth := "950mbit"
		if device == "pi3b" {
			bandwidth = "95mbit"
		}

		_, wErr = f.WriteString("sudo ./qdisc_setup_routing_device.bash " + device + " " + strconv.FormatInt(int64(di+1), base10) + " " + bandwidth)
		if wErr != nil {
			log.Fatal(err)
		}

		f.Close()

		log.Println("wrote file for:", device)

		cErr := os.Chmod(filename, 0755)
		if cErr != nil {
			fmt.Println("Error changing file mode:", err)
			return
		}

	}
}

// readFileToSlice reads the file and converst to a slice of lines
func readFileToSlice(filename string) (lines []string) {
	content, err := os.ReadFile(filename)
	if err != nil {
		log.Fatal("reading file error", err)
	}
	lines = strings.Split(strings.ToLower(string(content)), "\n")
	return lines
}
