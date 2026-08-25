PROJECT := Pawse.xcodeproj
SCHEME := Pawse
DESTINATION := platform=macOS
DERIVED_DATA ?= .build/DerivedData
XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath '$(DERIVED_DATA)'

.PHONY: list build test release clean verify

list:
	xcodebuild -list -project $(PROJECT)

build:
	$(XCODEBUILD) build

test:
	$(XCODEBUILD) test

release:
	$(XCODEBUILD) -configuration Release build

clean:
	$(XCODEBUILD) clean

verify: test
	git diff --check
