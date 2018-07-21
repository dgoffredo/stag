
BUILD_DIR = build/$(shell uname)

$(BUILD_DIR)/bin/stag: .make-init-ran-already $(shell find src/ -type f -name '*.rkt')
	mkdir -p $(BUILD_DIR)
	raco exe -o $(BUILD_DIR)/stag src/stag.rkt
	raco distribute $(BUILD_DIR) $(BUILD_DIR)/stag
	rm $(BUILD_DIR)/stag

.make-init-ran-already:
	git config core.hooksPath .githooks
	touch .make-init-ran-already

.PHONY: build init test

build: $(BUILD_DIR)/bin/stag

init: .make-init-ran-already

test: init
	raco test --quiet --quiet-program src/stag/*/test.rkt