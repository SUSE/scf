// -*- go -*-
package main

import (
	"fmt"
	"log"
	"io"
	"net/http"
	"os"
	"strings"

	"golang.org/x/net/websocket"
)

func main() {
	http.Handle("/echo", websocket.Handler(echoHandler))
	http.Handle("/static/", http.StripPrefix("/static/", http.FileServer(http.Dir("static"))))
	// - /static/ws.html
	// - /static/js/jquery-2.1.4.min.js
	http.HandleFunc("/env", envHandler)
	http.HandleFunc("/crash", crashHandler)
	http.HandleFunc("/headers", headersHandler)
	addr := ":" + os.Getenv("PORT")
	fmt.Printf("Listening on %v\n", addr)
	log.Fatal(http.ListenAndServe(addr, nil))
}

// envHandler prints out the environment seen by the backend/application/this process
func envHandler(w http.ResponseWriter, req *http.Request) {
	fmt.Printf("\n%+v\n\n", req)
	fmt.Fprintf(w,"\n%+v\n\n", req)
	fmt.Fprintln(w, strings.Join(os.Environ(), "\n"))
}

// crashHandler kills the application
func crashHandler(w http.ResponseWriter, req *http.Request) {
	fmt.Fprintf(w, "Crashing...")
	if flusher, ok := w.(http.Flusher); ok {
		flusher.Flush()
	}
	os.Exit(1)
}

// headerHandler prints out the active headers in the request
func headersHandler(w http.ResponseWriter, req *http.Request) {
	req.Header.Write(w)
}

func echoHandler(ws *websocket.Conn) {
	fmt.Printf("ECHO websock\n")
	io.Copy(ws, ws)
	fmt.Printf("OHCE websock\n")
}
