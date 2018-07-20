
BUILD_DIR = build/$(shell uname)

$(BUILD_DIR)/bin/stag: .make-init-ran-already $(shell find src/ -type f -name '*.rkt')
	mkdir -p $(BUILD_DIR)
	raco exe -o $(BUILD_DIR)/stag src/stag.rkt
	raco distribute $(BUILD_DIR) $(BUILD_DIR)/stag
	rm $(BUILD_DIR)/stag

.make-init-ran-already:
	git config core.hooksPath .githooks
	touch .make-init-ran-already

.PHONY: build
build: $(BUILD_DIR)/bin/stag

.PHONY: init
init: .make-init-ran-already

.PHONY: test
test: init
	raco test src/stag/*/test.rkt