SHELL = /bin/bash

OS_GO_BIN_NAME=go
ifeq ($(shell uname),Windows)
	OS_GO_BIN_NAME=go.exe
endif

OS_GO_OS=$(shell $(OS_GO_BIN_NAME) env GOOS)
#OS_GO_OS=windows # toggle to fake being windows..

BIN_ROOT=$(PWD)/.bin
export PATH:=$(PATH):$(BIN_ROOT)
DATA_ROOT=$(PWD)/.data

BIN_MAIN_NAME=pb-gen
ifeq ($(OS_GO_OS),windows)
	BIN_MAIN_NAME=pb-gen.exe
endif
BIN_MAIN=$(BIN_ROOT)/$(BIN_MAIN_NAME)
BIN_MAIN_WHICH=$(shell command -v $(BIN_MAIN_NAME))

# toggle for DEBUG or RELEASE based in CI env
#BIN_MAIN_CMD=$(BIN_MAIN_CMD_DEBUG)
BIN_MAIN_CMD=$(BIN_MAIN_CMD_RELEASE)
BIN_MAIN_CMD_DEBUG=$(BIN_MAIN_NAME) --dev --dir $(DATA_ROOT)/debug
BIN_MAIN_CMD_RELEASE=$(BIN_MAIN_NAME) --dir $(DATA_ROOT)/release

### TOOLS

BIN_GMU_NAME=go-mod-upgrade
ifeq ($(OS_GO_OS),windows)
	BIN_GMU_NAME=go-mod-upgrade.exe
endif
BIN_GMU_WHICH=$(shell command -v $(BIN_GMU_NAME))

BIN_CII_NAME=ci-info
ifeq ($(OS_GO_OS),windows)
	BIN_CII_NAME=ci-info.exe
endif
BIN_CII_WHICH=$(shell command -v $(BIN_CII_NAME))

.PHONY: help
help: # Show help for each of the Makefile recipes.
	@grep -E '^[a-zA-Z0-9 -]+:.*#'  Makefile | sort | while read -r l; do printf "\033[1;32m$$(echo $$l | cut -f 1 -d':')\033[00m:$$(echo $$l | cut -f 2- -d'#')\n"; done

print: # Prints all pertientn info we need.
	@echo ""
	@echo "OS_GO_BIN_NAME:   $(OS_GO_BIN_NAME)"
	@echo ""
	@echo "OS_GO_OS:         $(OS_GO_OS)"
	@echo ""
	@echo ""
	@echo "BIN_ROOT:         $(BIN_ROOT)"
	@echo "DATA_ROOT:        $(DATA_ROOT)"
	@echo ""
	@echo "bin:"
	@echo ""
	@echo "BIN_MAIN:                 $(BIN_MAIN)"
	@echo "BIN_MAIN_NAME:            $(BIN_MAIN_NAME)"
	@echo "BIN_MAIN_WHICH:           $(BIN_MAIN_WHICH)"
	@echo "BIN_MAIN_CMD:             $(BIN_MAIN_CMD)"
	@echo "BIN_MAIN_CMD_DEBUG:       $(BIN_MAIN_CMD_DEBUG)"
	@echo "BIN_MAIN_CMD_RELEASE:     $(BIN_MAIN_CMD_RELEASE)"

	@echo ""
	@echo "tools:"
	@echo ""
	@echo "BIN_GMU_NAME:     $(BIN_GMU_NAME)"
	@echo "BIN_GMU_WHICH:    $(BIN_GMU_WHICH)"
	@echo ""
	@echo "BIN_CII_NAME:     $(BIN_CII_NAME)"
	@echo "BIN_CII_WHICH:    $(BIN_CII_WHICH)"
	@echo ""

env-print: # Prints the environment we are running in.
	@echo ""
	@echo "ENV_GITHUB:       $(GITHUB_ACTIONS)"
	@echo "ENV_TRAVIS:       $(TRAVIS)"
	@echo "ENV_CIRCLECI:     $(CIRCLECI)"
	@echo "ENV_GITLAB_CI:    $(GITLAB_CI)"
	@echo ""

	@echo ""
	@echo "IS CI ?"
	$(BIN_CII_NAME) isci
	@echo "IS PR ?"
	$(BIN_CII_NAME) ispr
	@echo ""

### CI - Continuous integration

ci-build: # CI thats runs build, test, run cycle using current versions.
	@echo ""
	@echo "CI BUILD starting ..."

	$(MAKE) dep-mod-tidy
	$(MAKE) dep-tools
	$(MAKE) print
	$(MAKE) env-print
	$(MAKE) bin-clean
	$(MAKE) data-clean
	$(MAKE) gen
	$(MAKE) bin-build
	$(MAKE) run-migrate
	@echo ""
	@echo "CI BUILD ended ...."


ci-smoke: # CI that runs build, test, run cycle using the latest versions.
	@echo ""
	@echo "CI SMOLE starting ..."
	$(MAKE) dep-mod-tidy
	$(MAKE) dep-tools
	$(MAKE) dep-mod-up-force
	$(MAKE) print
	$(MAKE) env-print
	$(MAKE) bin-build
	$(MAKE) run-migrate
	@echo ""
	@echo "CI SMOKE ended ...."

### DEP - Dependencies

dep-tools: # Install tools needed. 

	# https://github.com/oligot/go-mod-upgrade
	# https://github.com/oligot/go-mod-upgrade/releases/tag/v0.9.1
	$(OS_GO_BIN_NAME) install github.com/oligot/go-mod-upgrade@v0.9.1

	# https://github.com/KlotzAndrew/ci-info
	# https://github.com/KlotzAndrew/ci-info/releases/tag/v0.2.0
	$(OS_GO_BIN_NAME) install github.com/klotzandrew/ci-info@v0.2.0

dep-mod-up: # Upgrade golang modules to latest Interactivly.
	$(OS_GO_BIN_NAME) mod tidy
	$(BIN_GMU_NAME)
	$(OS_GO_BIN_NAME) mod tidy
dep-mod-up-force: # Upgrade golang modules to latest Forcefully.
	$(OS_GO_BIN_NAME) mod tidy
	$(BIN_GMU_NAME) -f
	$(OS_GO_BIN_NAME) mod tidy
dep-mod-tidy: # Tidy the golang modules to versions in go.mod
	$(OS_GO_BIN_NAME) mod tidy

### GEN - generation.

gen-help:
	$(BIN_GEN_NAME) -h
gen: # Generate the golang code.
	# 1. Gen the golang model types off the Pocketbase DB.
	$(BIN_GEN_NAME) --verbose --db-path $(DATA_ROOT)/debug/data.db models
gen-clean: # Cleans generated code..
	rm -rf modelspb


### BIN - Binaires 

bin-init: 
	mkdir -p $(BIN_ROOT)
bin-clean:
	rm -rf $(BIN_ROOT)
bin-build: bin-init # Build the binary.
	cd cmd/pb-gen && $(OS_GO_BIN_NAME) build -o $(BIN_MAIN) .

### DATA 

data-init:
	mkdir -p $(DATA_ROOT)
data-clean:
	rm -rf $(DATA_ROOT)

### RUN

run-serve: # Serve
	$(BIN_MAIN_CMD) serve

	# Admin: 	http://127.0.0.1:8090/_/
	# Users: 	http://127.0.0.1:8090

	# user
	# joeblew99@gmail.com
	# password-known

run-admin: # Create Admin user
	$(BIN_MAIN_CMD) admin
	# admin
	# gedw99@gmail.com
	# password-known

run-migrate: # Create DB migrations.
	$(BIN_MAIN_CMD) migrate


### RELEASE

release-print: ## Print Releases
	@echo ""
	git tag --list
	@echo ""

release: # Release a new version. Example: make release V=0.0.0
	@read -p "Press enter to confirm and push to origin ..."
	git tag v$(V)
	git push origin v$(V)




