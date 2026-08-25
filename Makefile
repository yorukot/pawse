PROJECT := Pawse.xcodeproj
SCHEME := Pawse
DESTINATION := platform=macOS
DERIVED_DATA ?= .build/DerivedData
DIST_DIR ?= dist
VERSION ?=
XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath '$(DERIVED_DATA)'

.PHONY: list build test release clean verify release-check release-toolchain-check release-notes package

list:
	xcodebuild -list -project $(PROJECT)

build:
	$(XCODEBUILD) build

test:
	$(XCODEBUILD) test

release: release-toolchain-check
	$(XCODEBUILD) -configuration Release build

clean:
	$(XCODEBUILD) clean

verify: test
	git diff --check

release-check:
	./scripts/release/verify-version.sh $(VERSION)

release-toolchain-check:
	./scripts/release/verify-toolchain.sh

release-notes: release-check
	./scripts/release/release-notes.sh $(VERSION) $(DIST_DIR)/release-notes.md

package: release-check
	VERSION=$(VERSION) DERIVED_DATA=$(DERIVED_DATA) DIST_DIR=$(DIST_DIR) ./scripts/release/package-dmg.sh
