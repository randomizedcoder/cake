package main

import (
	"bufio"
	"flag"
	"fmt"
	"io/fs"
	"log"
	"os"
	"strings"
)

const (
	debugLevelCst = 11

	cakePathCst   = "/home/das/Downloads/cake"
	outputPathCst = "/tmp/qdisc/"
	reportNameCst = "report.csv"

	iperfOutFolderCst = "16_iperf"
	iperfStdOutCst    = "stdout"

	//base10 = 10
)

var (
	// Passed by "go build -ldflags" for the show version
	commit string
	date   string

	debugLevel int
)

func main() {

	version := flag.Bool("version", false, "version")

	debugLevelFlag := flag.Int("debugLevel", debugLevelCst, "nasty debugLevel")
	//cakePath := flag.String("cakePath", cakePathCst, "file path containing the config files")
	outputPath := flag.String("outputPath", outputPathCst, "Output path")
	iperfOutFolder := flag.String("iperfOutFolder", iperfOutFolderCst, "iperf output folder name")
	iperfStdOut := flag.String("iperfStdOut", iperfStdOutCst, "iperf stdout file name")
	reportName := flag.String("reportName", reportNameCst, "report csv filename")

	flag.Parse()

	if *version {
		fmt.Println("commit:", commit, "\tdate(UTC):", date)
		os.Exit(0)
	}

	debugLevel = *debugLevelFlag

	paths := Files(*outputPath, *iperfOutFolder, *iperfStdOut)

	var outputLines []string
	for _, path := range paths {

		parts := strings.Split(path, "/")
		device := parts[1]
		qdisc := parts[2]
		if debugLevel > 10 {
			//log.Println("path:", path)
			log.Println("parts:", parts)
			log.Println("device:", device, "qdisc:", qdisc)
		}

		lastLine := LastLine(*outputPath + path)

		// TCP window size:  977 KByte (default)
		// ------------------------------------------------------------
		// [SUM-cnt] Interval            Transfer    Bandwidth       Write/Err  Rtry
		// [SUM-40] 0.0000-10.0000 sec   815 MBytes   684 Mbits/sec  166951/164374      1485
		// [SUM-40] 10.0000-20.0000 sec   766 MBytes   643 Mbits/sec  152000/148954       261

		// [SUM-40] 880.0000-890.0000 sec   763 MBytes   640 Mbits/sec  143260/140103       265
		// [SUM-80] 890.0000-902.0881 sec   795 MBytes   551 Mbits/sec  152780/149627       251
		// [SUM-80] 0.0000-902.0881 sec  67.9 GBytes   647 Mbits/sec  12330163/5483     26905

		fields := strings.Fields(lastLine)
		mbs := ""
		if len(fields) > 5 {
			mbs = fields[5]
		}

		if debugLevel > 10 {
			log.Println("lastLine:", lastLine)
			log.Println("fields:", fields)
			log.Println("mbs:", mbs)
		}

		outputLines = append(outputLines, fmt.Sprintf("%s,%s,%s", device, qdisc, mbs))
	}

	err := writeLines(*outputPath+*reportName, outputLines)
	if err != nil {
		log.Fatal(err)
	}
}

// https://pkg.go.dev/io/fs#WalkDir
func Files(path string, searchFolder string, searchFile string) (paths []string) {
	fsys := os.DirFS(path)
	err := fs.WalkDir(fsys, ".", func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			log.Fatal(err)
		}
		if debugLevel > 10 {
			fmt.Println(path)
			fmt.Printf("File Name: %s\n", d.Name())
		}
		if strings.Contains(p, searchFolder) && strings.Contains(p, searchFile) {
			paths = append(paths, p)
		}
		return nil
	})
	if err != nil {
		log.Fatal(err)
	}
	return paths
}

func LastLine(file string) (lastLine string) {

	readFile, err := os.Open(file)

	if err != nil {
		log.Fatal(err)
	}
	defer readFile.Close()

	fileScanner := bufio.NewScanner(readFile)

	fileScanner.Split(bufio.ScanLines)

	for fileScanner.Scan() {
		lastLine = fileScanner.Text()
	}

	return lastLine
}

func writeLines(fn string, lines []string) (err error) {
	f, err := os.Create(fn)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()

	// header
	_, err = f.WriteString("device,qdisc,mbs\n")
	if err != nil {
		log.Fatal(err)
	}

	for _, line := range lines {
		_, err := f.WriteString(line + "\n")
		if err != nil {
			log.Fatal(err)
		}
	}
	return err
}
