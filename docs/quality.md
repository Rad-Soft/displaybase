# Quality checks

Every pull request and every push to `main` runs the same checks you can run on your Mac. `.github/workflows/ci.yml` calls the same scripts the Makefile does.

## What is checked

| Check | Tool | Gate |
| --- | --- | --- |
| Swift style | SwiftLint, strict (`.swiftlint.yml`) | No violations, warnings count |
| Dead Swift code | Periphery (`.periphery.yml`) | No findings |
| App tests | Swift Testing through `xcodebuild test` | All pass |
| App coverage | `xccov` over `Displaybase/Core` | At least 95% of lines |
| Site types | `next typegen`, then `tsc --noEmit` | No errors |
| Site lint | oxlint | No findings |
| Site dead code | knip (unused files and exports) | No findings |
| Duplication | jscpd over `site/src` and the Swift sources | At most 3% of lines |
| Site tests | `bun test --coverage`, only once site tests exist | All pass |
| Site build | `next build` | Builds |
| Report scripts | `bun test` over `.github/scripts/tests` | All pass |
| Workflow | actionlint | No findings |

A tool that crashes, is missing, or prints something unreadable fails its check. It never counts as clean.

## Coverage scope

Coverage is measured over every file in `Displaybase/Core`. Files that cannot run without hardware are excluded in one place, `.github/scripts/coverage-exclusions.ts`, with a reason per file. They still show in the report with their own numbers, so nothing is hidden. Do not add a file there to pass the gate; add a test or a seam instead.

The excluded files today are `DDC`, `DisplayLayout`, `Rotation`, `USBWatcher`, `WindowKeeper`, `RemoteComputer`, `Hotkey`, `Notifier` and any `Live*.swift`.

## Run it locally

You need Xcode 26 or later, [XcodeGen](https://github.com/yonaskolb/XcodeGen), SwiftLint, Periphery, [Bun](https://bun.sh) and actionlint.

```sh
brew install xcodegen swiftlint periphery actionlint oven-sh/bun/bun
```

| Command | What it does | Output |
| --- | --- | --- |
| `make lint` | SwiftLint strict, then Periphery | `build/lint/summary.json` |
| `make coverage` | Tests with coverage, then the 95% gate | `build/coverage/summary.json`, `build/coverage/result.xcresult` |
| `make site-check` | Install, typecheck, oxlint, knip, jscpd, site tests, build | `build/site/summary.json` |
| `make scripts-test` | Tests for the report scripts | |
| `make workflow-lint` | actionlint on the workflows | |
| `make check` | All of the above | |

`make test` still runs the tests alone. None of these launch the app or touch a monitor.

The site tool versions are pinned in `.github/scripts/site-report.ts` and run through `bunx`, so `site/package.json` stays as it is.

## What CI shows

Each job writes a `summary.json` and a job summary. On a pull request, one job reads the three summaries and keeps a single comment up to date with tests, coverage (including files under the gate), code smells by tool, dead code and duplication. A missing summary shows as a failure.

## Pull requests from forks

Everything runs on GitHub's own runners, so a pull request from a fork gets the same checks as any other. A maintainer approves the run first, because the repository requires approval for everyone outside it. Nothing uses `pull_request_target`, no job uses secrets, and the token is read only apart from the job that comments.

A fork's token can't comment, so those pull requests show the results in each job's summary instead of a comment.

Never add a self-hosted runner to this repository. A pull request can change the workflow and the scripts it runs.
