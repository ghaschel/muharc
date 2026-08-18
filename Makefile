SHELL := /bin/sh

VERSION := $(shell tr -d '\n' < VERSION)
RUNTIME := build/runtime

.PHONY: runtime test dist clean

runtime:
	mkdir -p $(RUNTIME)
	./scripts/build-wibo.sh --output $(RUNTIME)/wibo
	cp vendor/uharc/uharc.exe $(RUNTIME)/uharc.exe
	cp VERSION $(RUNTIME)/VERSION
	cp assets/completions/_uharc $(RUNTIME)/_uharc

test: runtime
	./tests/wrapper_test.sh
	./tests/release_workflow_test.sh
	./tests/uharc_integration_test.sh

dist: runtime
	@test -n "$(VERSION)" || (printf '%s\n' 'VERSION is required' >&2; exit 64)
	mkdir -p build/dist/muharc-$(VERSION)/bin build/dist/muharc-$(VERSION)/libexec/muharc build/dist/muharc-$(VERSION)/share/zsh/site-functions
	cp bin/uharc build/dist/muharc-$(VERSION)/bin/uharc
	cp $(RUNTIME)/wibo $(RUNTIME)/uharc.exe $(RUNTIME)/VERSION $(RUNTIME)/_uharc build/dist/muharc-$(VERSION)/libexec/muharc/
	cp assets/completions/_uharc build/dist/muharc-$(VERSION)/share/zsh/site-functions/_uharc
	cp LICENSE NOTICE CHANGELOG.md build/dist/muharc-$(VERSION)/
	tar -C build/dist -czf build/muharc-$(VERSION)-macos-x86_64.tar.gz muharc-$(VERSION)

clean:
	rm -rf build/runtime build/dist
