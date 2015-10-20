package main

import (
	"bufio"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"regexp"
)

type ctrMap map[string]string

func processDockerPSOutput(stdout io.ReadCloser, m chan ctrMap) {
	cm := make(ctrMap)
	scanner := bufio.NewScanner(stdout)
	ptn := regexp.MustCompile("^\\s*([\\w\\d]+)\\s+.*(cf-[\\w_]+)\\s*$")
	exited := regexp.MustCompile("Exited\\s+\\(\\d+\\)")
	for scanner.Scan() {
		line := scanner.Text()
		if exited.MatchString(line) {
			continue
		}
		match := ptn.FindStringSubmatch(line)
		if len(match) == 3 {
			cm[match[1]] = match[2]
		}
	}
	if err := scanner.Err(); err != nil {
		fmt.Printf("error reading stdout: %v\n", err)
	}
	m <- cm
}

func getContainerMap() map[string]string {
	cmd := exec.Command("docker", "ps", "-a")
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		log.Fatal(err)
	}
	cmChan := make(chan ctrMap)
	go processDockerPSOutput(stdout, cmChan)
	cmd.Run()
	return <- cmChan
}

func watchLogs(containerID string, containerName string, ch chan string) {
	cmd := exec.Command("docker", "logs", "--follow", containerID)
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		log.Fatal(err)
	}
	go func() {
		scanner := bufio.NewScanner(stdout)
		for scanner.Scan() {
			line := scanner.Text()
			ch <- string(fmt.Sprintf("%s:%s\n", containerName, line))
		}
		if err := scanner.Err(); err != nil {
			fmt.Println(os.Stderr, "error reading stdout: %v", err)
		}
	}()
	cmd.Run()		
}

func main() {
	m := getContainerMap()
	recv_chan := make(chan string)
	for k, v := range(m) {
		go watchLogs(k, v, recv_chan)
	}
	for true {
		fmt.Printf("%s", <- recv_chan)
	}
}
	
	
