
BUILD_DIR = build/$(shell uname)
SOURCES = $(shell find src/ -type f -name '*.rkt') README.md

$(BUILD_DIR)/bin/stag: $(SOURCES) .make-init-ran-already
	mkdir -p $(BUILD_DIR)
	raco exe -o $(BUILD_DIR)/stag src/stag/main.rkt
	raco distribute $(BUILD_DIR) $(BUILD_DIR)/stag
	rm $(BUILD_DIR)/stag

.make-init-ran-already:
	git config core.hooksPath .githooks
	touch .make-init-ran-already

.PHONY: build init test package examples clean

## Create self-contained distribution
build: $(BUILD_DIR)/bin/stag

## Initialize git hooks
init: .make-init-ran-already

## Run all of the unit tests
test: init
	raco test --quiet --quiet-program src/stag/*/test.rkt

## `raco pkg install` stag library
package: $(SOURCES)
	2>/dev/null raco pkg remove stag
	cd src/stag && raco pkg install

## Generate examples
examples:
	examples/run.sh

## Remove build and all build/run artifacts
clean:
	if [ -d build ]; then rm -r build; fi
	find . -type d -name 'compiled'    -exec rm -r {} +
	find . -type d -name '__pycache__' -exec rm -r {} +
	find . -type d -name '.mypy_cache' -exec rm -r {} +

# The "help" target and its associated code was copied from crifan's
# December 7, 2017 comment on <https://gist.github.com/prwhite/8168133>,
# accessed July 23, 2018.

# COLORS
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
WHITE  := $(shell tput -Txterm setaf 7)
RESET  := $(shell tput -Txterm sgr0)

TARGET_MAX_CHAR_NUM=20
## Show help
help:
	@echo ''
	@echo 'Usage:'
	@echo '  ${YELLOW}make${RESET} ${GREEN}<target>${RESET}'
	@echo ''
	@echo 'Targets:'
	@awk '/^[a-zA-Z\-\_0-9]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")-1); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf "  ${YELLOW}%-$(TARGET_MAX_CHAR_NUM)s${RESET} ${GREEN}%s${RESET}\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)

