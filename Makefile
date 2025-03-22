SHELL_FILES := $(wildcard lib/*.sh addons/*.sh) bin/pxh

.PHONY: lint fmt check list

lint:
	shellcheck $(SHELL_FILES)

fmt:
	shfmt -i 2 -w $(SHELL_FILES)

check:
	shfmt -i 2 -d $(SHELL_FILES)
	shellcheck $(SHELL_FILES)

list:
	@ls addons | sed 's/\.sh$$//'
