APP := build/Niche.app
PANEL := build/verify/panel
SIGN_ID ?= $(shell security find-identity -v -p codesigning | awk 'NR==1 && $$2 ~ /^[0-9A-F]+$$/ {print $$2}')

.PHONY: app run install test golden verify baseline clean

app:
	swift build -c release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp .build/release/Niche $(APP)/Contents/MacOS/Niche
	cp Info.plist $(APP)/Contents/Info.plist
	mkdir -p $(APP)/Contents/Resources
	-cp Assets/AirPods/*.mp4 $(APP)/Contents/Resources/
	mkdir -p $(APP)/Contents/Helpers
	cp .build/release/NicheCLI $(APP)/Contents/Helpers/niche
	codesign --force --sign $(or $(SIGN_ID),-) $(APP)/Contents/Helpers/niche
	codesign --force --sign $(or $(SIGN_ID),-) $(APP)

run: app
	-pkill -x Niche
	open $(APP)

install: app
	mkdir -p $(HOME)/.local/bin
	ln -sf $(abspath $(APP))/Contents/Helpers/niche $(HOME)/.local/bin/niche

test:
	swift test

golden:
	NICHE_RECORD=1 swift test --filter ContractTests
	git diff --stat -- Verify/golden

$(PANEL): Verify/panel.swift
	mkdir -p $(dir $(PANEL))
	swiftc -O Verify/panel.swift -o $(PANEL)

verify: $(PANEL)
	swift test
	$(MAKE) run
	python3 Verify/scenes.py check

baseline: run $(PANEL)
	python3 Verify/scenes.py record

clean:
	rm -rf .build build
