SHELL_FILES := $(wildcard lib/*.sh addons/*.sh tests/*.sh scripts/*.sh templates/*.sh) bin/pxh install.sh

.PHONY: help lint fmt check test list new-addon

help:
	@echo "make lint       run shellcheck"
	@echo "make fmt        format with shfmt"
	@echo "make check      formatting diff plus shellcheck"
	@echo "make test       smoke tests"
	@echo "make list       list addons"
	@echo "make new-addon  SLUG=name NAME=\"Display Name\""

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

new-addon:
	@bash scripts/new-addon.sh $(SLUG) "$(NAME)"
