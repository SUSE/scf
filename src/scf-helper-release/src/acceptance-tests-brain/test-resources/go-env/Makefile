all:	bin/go-env
	@echo "Launching at http://localhost:5050/"
	foreman start -p 5050

bin/go-env:
	GOBIN=bin go install
