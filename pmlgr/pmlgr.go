package main

import (
	"bufio"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"regexp"
	"strings"

	flags "github.com/jessevdk/go-flags"
)

type ctrMap map[string]string

type logMapT map[string][]string // Map a cf-[NAME] to a list of log files to track

func getLogMap() logMapT {
	return logMapT{
		"runner": []string{
			"/var/vcap/sys/log/dea_ctl.err.log",
			"/var/vcap/sys/log/warden/warden.log",
			"/var/vcap/sys/log/agent_ctl.err.log",
			"/var/vcap/sys/log/dea_next/dir_server.log",
			"/var/vcap/sys/log/dea_next/dea_next.log",
			"/var/vcap/sys/log/warden_ctl.log",
			"/var/vcap/sys/log/warden_ctl.err.log",
			"/var/vcap/sys/log/dea_logging_agent/dea_logging_agent.stdout.log",
			"/var/vcap/sys/log/dea_logging_agent/dea_logging_agent.stderr.log",
			"/var/vcap/sys/log/dea_ctl.log",
			"/var/vcap/sys/log/dir_server_ctl.err.log",
			"/var/vcap/sys/log/dea_logging_agent_ctl.log",
			"/var/vcap/sys/log/dea_logging_agent_ctl.err.log",
			"/var/vcap/sys/log/dir_server_ctl.log",
		},
		"router": []string{
			"/var/vcap/sys/log/gorouter/gorouter.log",
			"/var/vcap/sys/log/gorouter/access.log",
			"/var/vcap/sys/log/gorouter_ctl.err.log",
			"/var/vcap/sys/log/gorouter_ctl.log",
		},
		"hm9000": []string{
			"/var/vcap/sys/log/hm9000_evacuator_ctl.err.log",
			"/var/vcap/sys/log/hm9000_fetcher_ctl.err.log",
			"/var/vcap/sys/log/hm9000_shredder_ctl.log",
			"/var/vcap/sys/log/hm9000_sender_ctl.log",
			"/var/vcap/sys/log/hm9000_shredder_ctl.err.log",
			"/var/vcap/sys/log/hm9000_sender_ctl.err.log",
			"/var/vcap/sys/log/hm9000_analyzer_ctl.log",
			"/var/vcap/sys/log/hm9000_listener_ctl.log",
			"/var/vcap/sys/log/hm9000_api_server_ctl.log",
			"/var/vcap/sys/log/hm9000_listener_ctl.err.log",
			"/var/vcap/sys/log/hm9000_fetcher_ctl.log",
			"/var/vcap/sys/log/hm9000_metrics_server_ctl.log",
			"/var/vcap/sys/log/hm9000_evacuator_ctl.log",
			"/var/vcap/sys/log/hm9000/hm9000_analyzer.log",
			"/var/vcap/sys/log/hm9000/hm9000_metrics_server.log",
			"/var/vcap/sys/log/hm9000/hm9000_fetcher.log",
			"/var/vcap/sys/log/hm9000/hm9000_apiserver.log",
			"/var/vcap/sys/log/hm9000/hm9000_sender.log",
			"/var/vcap/sys/log/hm9000/hm9000_shredder.log",
			"/var/vcap/sys/log/hm9000/hm9000_listener.log",
			"/var/vcap/sys/log/hm9000/hm9000_evacuator.log",
			"/var/vcap/sys/log/hm9000_metrics_server_ctl.err.log",
			"/var/vcap/sys/log/hm9000_api_server_ctl.err.log",
			"/var/vcap/sys/log/hm9000_analyzer_ctl.err.log",
		},
		"api_worker": []string{
			"/var/vcap/sys/log/cloud_controller_worker_ctl.err.log",
			"/var/vcap/sys/log/cloud_controller_worker_ctl.log",
			"/var/vcap/sys/log/cloud_controller_worker/cloud_controller_worker.log",
		},
		"clock_global": []string{
			"/var/vcap/sys/log/cloud_controller_clock/cloud_controller_clock.log",
			"/var/vcap/sys/log/cloud_controller_clock_ctl.err.log",
			"/var/vcap/sys/log/cloud_controller_clock_ctl.log",
		},
		"uaa": []string{
			"/var/vcap/sys/log/uaa/host-manager.log",
			"/var/vcap/sys/log/uaa/uaa.log",
			"/var/vcap/sys/log/uaa/manager.log",
			"/var/vcap/sys/log/uaa/cf-registrar.log",
			"/var/vcap/sys/log/uaa/localhost.log",
			"/var/vcap/sys/log/uaa/catalina.log",
			"/var/vcap/sys/log/uaa/localhost_access.log",
			"/var/vcap/sys/log/uaa/varz.log",
			"/var/vcap/sys/log/uaa_ctl.err.log",
			"/var/vcap/sys/log/uaa_cf-registrar_ctl.err.log",
			"/var/vcap/sys/log/uaa_ctl.log",
			"/var/vcap/sys/log/uaa_cf-registrar_ctl.log",
		},
		"stats": []string{
			"/var/vcap/sys/log/collector/collector.log",
			"/var/vcap/sys/log/collector_ctl.log",
			"/var/vcap/sys/log/collector_ctl.err.log",
		},
		"postgres": []string{
			"/var/vcap/sys/log/postgres_ctl.err.log",
			"/var/vcap/sys/log/postgres/postgresql.log",
			"/var/vcap/sys/log/postgres_ctl.log",
		},
		"nats": []string{
			"/var/vcap/sys/log/nats_stream_forwarder_ctl.err.log",
			"/var/vcap/sys/log/nats_ctl.err.log",
			"/var/vcap/sys/log/nats_stream_forwarder_ctl.log",
			"/var/vcap/sys/log/nats/nats.log",
			"/var/vcap/sys/log/nats_ctl.log",
		},
		"api": []string{
			"/var/vcap/sys/log/cloud_controller_ng_ctl.err.log",
			"/var/vcap/sys/log/routing-api/routing-api.log",
			"/var/vcap/sys/log/cloud_controller_ng/cloud_controller_ng.log",
			"/var/vcap/sys/log/statsd-injector-ctl.log",
			"/var/vcap/sys/log/cloud_controller_migration_ctl.err.log",
			"/var/vcap/sys/log/statsd-injector/statsd_injector.stderr.log",
			"/var/vcap/sys/log/statsd-injector/statsd_injector.stdout.log",
			"/var/vcap/sys/log/routing-api_ctl.err.log",
			"/var/vcap/sys/log/nginx_ctl.err.log",
			"/var/vcap/sys/log/cloud_controller_migration_ctl.log",
			"/var/vcap/sys/log/cloud_controller_worker_ctl.err.log",
			"/var/vcap/sys/log/nginx_cc/nginx_status.access.log",
			"/var/vcap/sys/log/nginx_cc/nginx.error.log",
			"/var/vcap/sys/log/nginx_cc/nginx.access.log",
			"/var/vcap/sys/log/nginx_ctl.log",
			"/var/vcap/sys/log/statsd-injector-ctl.err.log",
			"/var/vcap/sys/log/cloud_controller_worker_ctl.log",
			"/var/vcap/sys/log/cloud_controller_ng_ctl.log",
			"/var/vcap/sys/log/routing-api_ctl.log",
		},
	}
}

func stringSliceMember(needle string, haystack []string) bool {
	for _, s := range haystack {
		if s == needle {
			return true
		}
	}
	return false
}

func processDockerPSOutput(roleNamesToExclude, roleNamesToInclude []string,
	stdout io.ReadCloser, m chan ctrMap) {
	cm := make(ctrMap)
	scanner := bufio.NewScanner(stdout)
	ptn := regexp.MustCompile(`^([\w\d]+)\s+.*?/cf-v\d+-([\w\d_]+):`)
	for scanner.Scan() {
		line := scanner.Text()
		match := ptn.FindStringSubmatch(line)
		if len(match) == 3 &&
			!stringSliceMember(match[2], roleNamesToExclude) &&
			(len(roleNamesToInclude) == 0 || stringSliceMember(match[2], roleNamesToInclude)) {
			cm[match[2]] = match[1]
		}
	}
	if err := scanner.Err(); err != nil {
		fmt.Printf("error reading stdout: %v\n", err)
	}
	m <- cm
}

func getContainerMap(roleNamesToExclude, roleNamesToInclude []string) map[string]string {
	cmd := exec.Command("docker", "ps", "--format", "{{.ID}} {{.Image}}")
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		log.Fatal(err)
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		log.Fatal(err)
	}
	go func() {
		_, _ = io.Copy(os.Stderr, stderr)
	}()
	cmChan := make(chan ctrMap)
	go processDockerPSOutput(roleNamesToExclude, roleNamesToInclude, stdout, cmChan)
	err = cmd.Run()
	if err != nil {
		log.Fatal(err)
	}
	return <-cmChan
}

func watchLogs(containerID string, roleName string, logFiles []string, ch chan string) {
	if len(logFiles) == 0 {
		fmt.Fprintf(os.Stderr, "No logFiles to watch for role %s\n", roleName)
		return
	}
	cmd := exec.Command("docker", "exec", containerID, "bash", "-c", "tail -F "+strings.Join(logFiles, " "))
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		log.Fatal(err)
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		log.Fatal(err)
	}
	go func() {
		fmt.Fprintf(os.Stderr, "docker exec bash -c tail ... Error output:")
		_, _ = io.Copy(os.Stderr, stderr)
		fmt.Fprintf(os.Stderr, "\n")
	}()
	go func() {
		scanner := bufio.NewScanner(stdout)
		for scanner.Scan() {
			line := scanner.Text()
			ch <- string(fmt.Sprintf("%s:%s\n", roleName, line))
		}
		if err := scanner.Err(); err != nil {
			fmt.Fprintf(os.Stderr, "error reading stdout: %v\n", err)
		}
	}()
	_ = cmd.Run()
}

func filterLogs(roleNamesToExclude, roleNamesToInclude []string) {
	m := getContainerMap(roleNamesToExclude, roleNamesToInclude)
	logMap := getLogMap()
	recvChan := make(chan string)
	numLogsToWatch := 0
	for roleName, containerID := range m {
		logFiles, ok := logMap[roleName]
		if !ok {
			fmt.Fprintf(os.Stderr, "No log files for role %s, skipping\n", roleName)
			continue
		}
		numLogsToWatch++
		go watchLogs(containerID, roleName, logFiles, recvChan)
	}
	if numLogsToWatch == 0 {
		fmt.Fprintf(os.Stderr, "Nothing to watch\n")
		return
	}
	for true {
		fmt.Printf("%s", <-recvChan)
	}
}

func main() {
	var opts struct {
		Exclude []string `short:"x" long:"exclude" description:"Exclude this role"`
	}
	args, err := flags.Parse(&opts)
	if err != nil {
		fmt.Printf("Error parsing %v\n", os.Args)
		os.Exit(1)
	}
	duplicateNames := []string{}
	for _, nameToExclude := range opts.Exclude {
		if stringSliceMember(nameToExclude, args) {
			duplicateNames = append(duplicateNames, nameToExclude)
		}
	}
	if len(duplicateNames) > 0 {
		fmt.Fprintf(os.Stderr, "The name(s) %s is/are in both inclusion and exclusion lists\n", duplicateNames)
		os.Exit(1)
	}
	filterLogs(opts.Exclude, args)
}
