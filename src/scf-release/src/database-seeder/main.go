// Database-seeder preseeds an external database server with the provided
// databases.
package main

import (
	"database/sql"
	"encoding/json"
	"flag"
	"fmt"
	"os"

	_ "github.com/go-sql-driver/mysql"
)

// SeedConfig describes the structure for database seeding configuration
type SeedConfig struct {
	Name     string
	Username string
	Password string
}

type dbCreator func(*sql.DB, SeedConfig) error

func mysqlCreator(db *sql.DB, seedConfig SeedConfig) (err error) {

	exec := func(stmt string, args ...interface{}) (sql.Result, error) {
		finalStmt := fmt.Sprintf(stmt, args...)
		// fmt.Printf("%s\n", finalStmt)
		return db.Exec(finalStmt)
	}

	// Create the database
	_, err = exec("CREATE DATABASE IF NOT EXISTS `%s`", seedConfig.Name)
	if err != nil {
		return err
	}

	// Create the user, or set the password if it already exists
	result, err := exec("CREATE USER IF NOT EXISTS `%s` IDENTIFIED BY '%s'",
		seedConfig.Username, seedConfig.Password)
	if err != nil {
		return err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows < 1 {
		_, err := exec("ALTER USER `%s` IDENTIFIED BY '%s'",
			seedConfig.Username, seedConfig.Password)
		if err != nil {
			return err
		}
	}

	// Grant privileges
	_, err = exec("GRANT ALL ON `%s`.* TO `%s`@`%%`", seedConfig.Name, seedConfig.Username)
	if err != nil {
		return err
	}

	_, err = exec("REVOKE LOCK TABLES ON `%s`.* FROM `%s`@`%%`", seedConfig.Name, seedConfig.Username)
	if err != nil {
		return err
	}

	return nil
}

func main() {
	var driver, dsn, seedConfigsJSON string

	flag.StringVar(&driver, "driver", "mysql", "Database driver to use")
	flag.StringVar(&dsn, "dsn", "", "Database connection string (DSN) to use (SEEDER_DSN)")
	flag.StringVar(&seedConfigsJSON, "seed-configs", "", "Database seeding configuration, as a JSON string (SEEDER_CONFIGS)")
	flag.Parse()

	if dsn == "" {
		dsn = os.Getenv("SEEDER_DSN")
	}
	if seedConfigsJSON == "" {
		seedConfigsJSON = os.Getenv("SEEDER_CONFIGS")
	}

	var seedConfigs []SeedConfig
	err := json.Unmarshal([]byte(seedConfigsJSON), &seedConfigs)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Could not parse seed configs: %v\n", err)
		os.Exit(1)
	}

	db, err := sql.Open(driver, dsn)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error connecting to database: %s\n", err)
		os.Exit(1)
	}

	creator := map[string]dbCreator{
		"mysql": mysqlCreator,
	}[driver]
	if creator == nil {
		fmt.Fprintf(os.Stderr, "Error locating db creator for driver %s\n", driver)
		os.Exit(1)
	}

	hasError := false

	for _, seedConfig := range seedConfigs {
		fmt.Printf("Seeding database %s (user %s)...\n", seedConfig.Name, seedConfig.Username)
		err = creator(db, seedConfig)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error creating database %s: %v\n", seedConfig.Name, err)
			hasError = true
		}
	}

	if hasError {
		os.Exit(1)
	}

	fmt.Printf("Database seeding complete.")
}
