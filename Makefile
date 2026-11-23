APP = build/Build/Products/Release/Displaybase.app

.PHONY: project build test install lint coverage site-install site-check scripts-test workflow-lint check

project:
	xcodegen generate --quiet

build: project
	xcodebuild -project Displaybase.xcodeproj -scheme Displaybase -configuration Release -derivedDataPath build -quiet build

test: project
	xcodebuild -project Displaybase.xcodeproj -scheme Displaybase -derivedDataPath build -quiet test

COVERAGE_DIR = build/coverage

# strict SwiftLint, then Periphery on the generated project
lint: project
	bun run .github/scripts/lint-report.ts

# runs the tests with coverage, then gates Core lines at 95%
coverage: project
	rm -rf $(COVERAGE_DIR)
	xcodebuild -project Displaybase.xcodeproj -scheme Displaybase -derivedDataPath $(COVERAGE_DIR) -enableCodeCoverage YES -resultBundlePath $(COVERAGE_DIR)/result.xcresult -quiet test; \
	status=$$?; \
	bun run .github/scripts/swift-coverage.ts --bundle $(COVERAGE_DIR)/result.xcresult --out $(COVERAGE_DIR) || status=1; \
	exit $$status

site-install:
	cd site && bun install --frozen-lockfile

# typecheck, oxlint, knip, jscpd, site tests and next build
site-check: site-install
	bun run .github/scripts/site-report.ts

scripts-test:
	bun test ./.github/scripts/tests

workflow-lint:
	actionlint

check: lint coverage site-check scripts-test workflow-lint

# quit it first, so it can bring your screens back
install: build
	-osascript -e 'tell application "Displaybase" to quit' 2>/dev/null
	while pgrep -x Displaybase >/dev/null; do sleep 1; done
	rm -rf /Applications/Displaybase.app
	cp -R $(APP) /Applications/
	open /Applications/Displaybase.app
