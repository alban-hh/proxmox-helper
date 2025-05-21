SHELL_FILES := $(wildcard lib/*.sh addons/*.sh tests/*.sh) bin/pxh

.PHONY: lint fmt check test list

lint:
	shellcheck $(SHELL_FILES)

fmt:
	shfmt -i 2 -w $(SHELL_FILES)

check:
	shfmt -i 2 -d $(SHELL_FILES)
	shellcheck $(SHELL_FILES)

test:
	bash tests/smoke.sh

list:
	@ls addons | sed 's/\.sh$$//'
