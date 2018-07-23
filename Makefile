
BUILD_DIR = build/$(shell uname)
SOURCES = $(shell find src/ -type f -name '*.rkt') README.md

# Create a self-contained distribution of the stag command line tool.
$(BUILD_DIR)/bin/stag: $(SOURCES) .make-init-ran-already
	mkdir -p $(BUILD_DIR)
	raco exe -o $(BUILD_DIR)/stag src/stag/main.rkt
	raco distribute $(BUILD_DIR) $(BUILD_DIR)/stag
	rm $(BUILD_DIR)/stag

# Initialize git hooks.
.make-init-ran-already:
	git config core.hooksPath .githooks
	touch .make-init-ran-already

.PHONY: build init test package examples

# Create a self-contained distribution of the stag command line tool.
build: $(BUILD_DIR)/bin/stag

# Initialize git hooks.
init: .make-init-ran-already

# Run all of the unit tests.
test: init
	raco test --quiet --quiet-program src/stag/*/test.rkt

# Install stag as a Racket package.
package: $(SOURCES)
	2>/dev/null raco pkg remove stag
	cd src/stag && raco pkg install

# Generate examples
examples:
	examples/run.sh