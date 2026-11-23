import { mkdirSync, readdirSync, writeFileSync } from "node:fs"
import { join } from "node:path"
import {
  computeCoverage,
  parseTests,
  renderCoverage,
  type CoverageSummary,
} from "./coverage"
import { arg, crashDetail, parseJson, publish, run } from "./report"

const bundle = arg("bundle", "build/coverage/result.xcresult")
const out = arg("out", "build/coverage")
const core = arg("core", "Displaybase/Core")
const threshold = Number(arg("threshold", "95"))

function coreFiles(dir: string): string[] {
  return readdirSync(dir, { recursive: true })
    .map(String)
    .filter((f) => f.endsWith(".swift"))
    .sort()
    .map((f) => join(dir, f))
}

function main(): CoverageSummary {
  const base = {
    name: "app" as const,
    threshold,
    tests: null,
    lines: 0,
    covered: 0,
    executable: 0,
    files: [],
  }
  const fail = (error: string): CoverageSummary => ({
    ...base,
    ok: false,
    error,
  })

  const xccov = run("xcrun", ["xccov", "view", "--report", "--json", bundle])
  const report = xccov.status === 0 ? parseJson(xccov.stdout) : null
  if (report === null) return fail(`xccov failed: ${crashDetail(xccov)}`)

  const result = computeCoverage(report, coreFiles(core), { threshold })

  const testRun = run("xcrun", [
    "xcresulttool",
    "get",
    "test-results",
    "summary",
    "--path",
    bundle,
    "--compact",
  ])
  const tests = testRun.status === 0 ? parseTests(parseJson(testRun.stdout)) : null
  const testsOk = tests !== null && tests.failed === 0 && tests.result === "Passed"
  const error =
    result.error ??
    (tests === null
      ? `test summary unreadable: ${crashDetail(testRun)}`
      : testsOk
        ? undefined
        : `${tests.failed} test(s) failed`)
  return {
    ...base,
    ok: result.ok && testsOk,
    error,
    tests,
    lines: result.lines,
    covered: result.covered,
    executable: result.executable,
    files: result.files,
  }
}

let summary: CoverageSummary
try {
  summary = main()
} catch (e) {
  summary = {
    name: "app",
    threshold,
    ok: false,
    error: e instanceof Error ? e.message : String(e),
    tests: null,
    lines: 0,
    covered: 0,
    executable: 0,
    files: [],
  }
}
mkdirSync(out, { recursive: true })
writeFileSync(join(out, "summary.json"), JSON.stringify(summary, null, 2))
publish(renderCoverage(summary))
console.log(
  `app: lines ${summary.lines.toFixed(2)}% gate ${threshold}% -> ${summary.ok ? "PASS" : "FAIL"}`
)
process.exit(summary.ok ? 0 : 1)
