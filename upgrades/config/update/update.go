package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"

	"github.com/hashicorp/consul/api"
	"github.com/hpcloud/gato/util"
)

type AddDeleteEntry map[string]string

type ChangeEntry map[string][2]string

type ChangesConfig struct {
	Changes   ChangeEntry    `json:"change"`
	Additions AddDeleteEntry `json:"add"`
	Deletions AddDeleteEntry `json:"drop"`
}

func main() {
	if len(os.Args) < 3 {
		fmt.Printf("Usage: update gato-url (e.g. http://localhost:8501) config-diffs-json file\n")
		return
	}
	gato_url := os.Args[1]
	if gato_url[len(gato_url)-1] == '/' {
		gato_url = gato_url[0 : len(gato_url)-1]
	}
	filename := os.Args[2]

	var config ChangesConfig
	var data []byte
	data, err := ioutil.ReadFile(filename)
	if err != nil {
		fmt.Printf("Can't open file %s for reading: %s\n", filename, err)
		return
	}

	err = json.Unmarshal(data, &config)
	if err != nil {
		fmt.Printf("Can't json-decode %s from <<%s>>: %s\n", filename, data, err)
		return
	}

	consulClient, err := util.NewConsulClient(gato_url)
	kv := consulClient.KV()
	if err != nil {
		fmt.Errorf("Can't get a handle to consul: %s\n", err)
		return
	}
	for k, v := range config.Deletions {
		currVal, _, err := kv.Get(k, nil)
		if err != nil {
			fmt.Printf("del: couldn't find key %s, err:%s\n", k, err)
			if fmt.Sprintf("%s, err") == "dial tcp: unknown port tcp/8501" {
				fmt.Printf("can't connect to consul: give up\n")
				return
			}
			continue
		} else if currVal == nil {
			fmt.Printf("del: couldn't find key %s\n", k)
			continue
		}
		if string(currVal.Value) != v {
			fmt.Printf("del: different value: old:%s, new:%s, not deleting\n", currVal.Value, v)
			continue
		}
		kv.Delete(k, nil)
	}
	wOpts := &api.WriteOptions{}
	for k, v := range config.Additions {
		kvp := &api.KVPair{Key: k, Value: []byte(v)}
		_, err := kv.Put(kvp, wOpts)
		if err != nil {
			fmt.Printf("add: failed to write key:%s, value:%s, err:%s\n", k, v, err)
		}
	}
	for k, v := range config.Changes {
		currVal, _, err := kv.Get(k, nil)
		if err != nil {
			fmt.Printf("change: failed to get a value for key %s, err:%s\n", k, err)
			continue
		}
		vOld, vNew := v[0], v[1]
		if currVal != nil && string(currVal.Value) != vOld {
			fmt.Printf("change: old value:%s, new value:%s, current value:%s\n", vOld, vNew, currVal.Value)
			continue
		}
		kvp := &api.KVPair{Key: k, Value: []byte(vNew)}
		_, err = kv.Put(kvp, wOpts)
		if err != nil {
			fmt.Printf("add: failed to write key:%s, value:%s, err:%s\n", k, v, err)
		}
	}
}
