package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"runtime"
	"strings"

	nats "github.com/nats-io/go-nats"
)

const ALIASES_FILE = "/avahi-aliases"

var aliases = make(map[string]bool)

func readAliases() {
	f, err := os.Open(ALIASES_FILE)
	if err != nil {
		log.Printf("Cannot open '%s' for reading: %s", ALIASES_FILE, err)
		return
	}
	defer f.Close()
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if len(line) > 0 && line[0] != '#' {
			aliases[line] = true
		}
	}
}

func registerAlias(uri string) {
	if aliases[uri] {
		return
	}
	aliases[uri] = true

	if strings.HasPrefix(uri, "*.") {
		log.Printf("Can't register wildcard URI '%s'", uri)
		return
	}

	f, err := os.OpenFile(ALIASES_FILE, os.O_APPEND|os.O_WRONLY, 0600)
	if err != nil {
		log.Printf("Can't open '%s' for appending: %s", ALIASES_FILE, err)
		return
	}

	defer f.Close()

	log.Printf("Registering '%s'", uri)
	if _, err = f.WriteString(fmt.Sprintf("\n%s", uri)); err != nil {
		log.Printf("Error while appending to '%s': %s", ALIASES_FILE, err)
	}

}

func main() {
	log.SetOutput(os.Stdout)

	readAliases()

	natsURL := os.Args[1]
	log.Println("connecting to:", natsURL)
	nc, err := nats.Connect(natsURL)
	if err != nil {
		log.Println("could not connect to nats:", err)
		return
	}

	nc.Subscribe("router.register", func(msg *nats.Msg) {
		// log.Printf("Received message '%s\n", string(msg.Data)+"'")
		var data map[string]interface{}
		if err := json.Unmarshal(msg.Data, &data); err != nil {
			log.Printf("Cannot decode JSON: '%s'", msg.Data)
		} else {
			URIs := data["uris"].([]interface{})
			for _, uri := range URIs {
				registerAlias(uri.(string))
			}
		}
	})
	runtime.Goexit()
}
