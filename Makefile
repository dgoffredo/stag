
.PHONY: init
init:
	git config core.hooksPath .githooks

BUILD_DIR = build/$(shell uname)
.PHONY: build
build: init
	mkdir -p $(BUILD_DIR)
	raco exe -o $(BUILD_DIR)/stag src/stag/stag.rkt
	raco distribute $(BUILD_DIR) $(BUILD_DIR)/stag
	rm $(BUILD_DIR)/stag

.PHONY: test
test: init
	raco test src/*/test.rkt