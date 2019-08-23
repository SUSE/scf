package main

import (
	"database/sql"
	"fmt"
	"os"

	_ "github.com/go-sql-driver/mysql"
	_ "github.com/lib/pq"
)

func main() {
	if len(os.Args) != 3 {
		fmt.Printf("Usage: %s <driver> <DSN>\n", os.Args[0])
		os.Exit(1)
	}

	driverName := os.Args[1]
	dsn := os.Args[2]

	db, err := sql.Open(driverName, dsn)
	if err != nil {
		fmt.Fprintf(
			os.Stderr,
			"Failed to open connection to %s (driver %s): %v\n",
			dsn, driverName, err)
		os.Exit(1)
	}

	err = db.Ping()
	if err != nil {
		fmt.Fprintf(
			os.Stderr,
			"Failed to ping database: %v\n",
			err)
		os.Exit(1)
	}

	fmt.Printf("Database connection established.\n")
}
