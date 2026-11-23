import { afterEach, expect, test } from "bun:test"
import { spawnSync } from "node:child_process"
import {
  chmodSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs"
import { tmpdir } from "node:os"
import { join, resolve } from "node:path"
import { computeCoverage } from "../coverage"
import { exclusionFor } from "../coverage-exclusions"
import {
  parseJscpd,
  parseKnip,
  parseOxlint,
  parsePeriphery,
  parseSwiftlint,
  parseTsc,
} from "../parsers"
import type { RunResult } from "../report"

const scripts = new URL("../", import.meta.url).pathname
const temporary: string[] = []

afterEach(() => {
  for (const path of temporary.splice(0))
    rmSync(path, { recursive: true, force: true })
})

const ran = (stdout: string, status = 0, extra: Partial<RunResult> = {}): RunResult => ({
  status,
  signal: null,
  stdout,
  stderr: "",
  error: null,
  ...extra,
})

// parsers

test("swiftlint findings become rows with relative paths", () => {
  const out = JSON.stringify([
    { file: "/repo/App/A.swift", line: 4, rule_id: "force_cast", reason: "no" },
  ])
  const r = parseSwiftlint(ran(out, 2), "/repo")
  expect(r.ok).toBe(false)
  expect(r.findings).toEqual([
    { file: "App/A.swift", line: 4, rule: "force_cast", message: "no" },
  ])
})

test("swiftlint passes only on an empty report with exit 0", () => {
  expect(parseSwiftlint(ran("[]")).ok).toBe(true)
})

test("swiftlint fails closed on malformed output, a crash and a missing binary", () => {
  expect(parseSwiftlint(ran("not json", 0)).ok).toBe(false)
  expect(parseSwiftlint(ran("[]", 1)).detail).toContain("tool failed")
  expect(parseSwiftlint(ran("[1]", 2)).detail).toContain("tool failed")
  const missing = ran("", null, { error: "spawn swiftlint ENOENT" })
  expect(parseSwiftlint(missing).detail).toContain("ENOENT")
})

test("periphery drops silgen stub parameters and keeps real findings", () => {
  const out = JSON.stringify([
    { kind: "var.parameter", name: "svc", hints: ["unused"], location: "A.swift:2:9" },
    { kind: "function", name: "dead()", hints: ["unused"], location: "A.swift:5:3" },
  ])
  const lines = ["@_silgen_name(\"X\")", "private func X(_ svc: Int)", "", "", "func dead() {}"]
  const r = parsePeriphery(ran(out), () => lines)
  expect(r.findings).toHaveLength(1)
  expect(r.findings[0]).toMatchObject({ file: "A.swift", line: 5, rule: "unused" })
})

test("periphery fails closed on malformed output and a crash", () => {
  expect(parsePeriphery(ran("warning: nope")).ok).toBe(false)
  expect(parsePeriphery(ran("[]", 1)).detail).toContain("tool failed")
  expect(parsePeriphery(ran('[{"location":"bad"}]')).detail).toContain("tool failed")
})

test("tsc errors are parsed and a silent nonzero exit is a crash", () => {
  const out = "src/a.ts(3,5): error TS2322: Type 'x' is not assignable.\n"
  const r = parseTsc(ran(out, 2))
  expect(r.findings[0]).toMatchObject({ file: "src/a.ts", line: 3, rule: "TS2322" })
  expect(parseTsc(ran("", 0)).ok).toBe(true)
  expect(parseTsc(ran("boom", 1)).detail).toContain("tool failed")
  expect(parseTsc(ran(out, 0)).ok).toBe(false)
})

test("oxlint reads diagnostics and fails closed on garbage", () => {
  const out = JSON.stringify({
    diagnostics: [
      { filename: "a.tsx", code: "no-unused-vars", message: "m", labels: [{ span: { line: 7 } }] },
    ],
  })
  expect(parseOxlint(ran(out, 1)).findings[0]).toMatchObject({ line: 7, rule: "no-unused-vars" })
  expect(parseOxlint(ran('{"diagnostics":[]}')).ok).toBe(true)
  expect(parseOxlint(ran("oops", 0)).ok).toBe(false)
  expect(parseOxlint(ran('{"diagnostics":[]}', 2)).detail).toContain("tool failed")
})

test("knip reads unused files and exports and fails closed on garbage", () => {
  const out = JSON.stringify({
    files: ["src/orphan.ts"],
    issues: [{ file: "src/b.ts", exports: [{ name: "unused", line: 3 }] }],
  })
  const r = parseKnip(ran(out, 1))
  expect(r.count).toBe(2)
  expect(r.findings[1]).toMatchObject({ rule: "exports", line: 3, message: "unused" })
  expect(parseKnip(ran('{"issues":[]}')).ok).toBe(true)
  expect(parseKnip(ran("", 1)).ok).toBe(false)
  expect(parseKnip(ran('{"issues":[]}', 2)).detail).toContain("tool failed")
})

const jscpdReport = (percentage: number) =>
  JSON.stringify({
    statistics: { total: { percentage, lines: 100, duplicatedLines: percentage } },
    duplicates: [
      {
        lines: 5,
        firstFile: { name: "/r/a.ts", startLoc: { line: 2 } },
        secondFile: { name: "/r/b.ts", startLoc: { line: 9 } },
      },
    ],
  })

test("jscpd enforces the percentage gate", () => {
  expect(parseJscpd(ran("", 0), jscpdReport(2.9), 3, "/r").ok).toBe(true)
  const over = parseJscpd(ran("", 1), jscpdReport(3.5), 3, "/r")
  expect(over.ok).toBe(false)
  expect(over.findings[0]).toMatchObject({ file: "a.ts", line: 2, message: "also at b.ts:9" })
})

test("jscpd fails closed without a readable report or on a crash", () => {
  expect(parseJscpd(ran("", 0), null, 3).ok).toBe(false)
  expect(parseJscpd(ran("", 0), "{}", 3).ok).toBe(false)
  expect(parseJscpd(ran("", 0), "garbage", 3).ok).toBe(false)
  expect(parseJscpd(ran("", 2), jscpdReport(0), 3).detail).toContain("tool failed")
})

// coverage

const entry = (path: string, covered: number, executable: number) => ({
  path: `/repo/${path}`,
  coveredLines: covered,
  executableLines: executable,
})
const xccov = (files: ReturnType<typeof entry>[], name = "DisplaybaseTests.xctest") => ({
  targets: [
    { name: "Displaybase.app", files: [entry("Displaybase/Core/A.swift", 0, 100)] },
    { name, files },
  ],
})

test("coverage gates the non-excluded Core files and lists the excluded ones", () => {
  const core = ["Displaybase/Core/A.swift", "Displaybase/Core/DDC.swift"]
  const data = xccov([
    entry("Displaybase/Core/A.swift", 95, 100),
    entry("Displaybase/Core/DDC.swift", 0, 200),
  ])
  const r = computeCoverage(data, core, { threshold: 95, root: "/repo" })
  expect(r.ok).toBe(true)
  expect(r.executable).toBe(100)
  expect(r.files.find((f) => f.file.endsWith("DDC.swift"))).toMatchObject({
    excluded: true,
    lines: 0,
  })
  expect(r.files.find((f) => f.file.endsWith("DDC.swift"))?.reason).toBeTruthy()
})

test("coverage fails just under the gate and never reads the app target", () => {
  const core = ["Displaybase/Core/A.swift"]
  const r = computeCoverage(xccov([entry("Displaybase/Core/A.swift", 94, 100)]), core, {
    threshold: 95,
    root: "/repo",
  })
  expect(r.ok).toBe(false)
  expect(r.lines).toBe(94)
})

test("a Core file the report lacks has no lines and an empty report is an error", () => {
  const core = ["Displaybase/Core/A.swift", "Displaybase/Core/Spot.swift"]
  const r = computeCoverage(xccov([entry("Displaybase/Core/A.swift", 10, 10)]), core, {
    threshold: 95,
    root: "/repo",
  })
  expect(r.ok).toBe(true)
  expect(r.files[1]).toMatchObject({ missing: true, executable: 0 })
  const none = computeCoverage(xccov([]), core, { threshold: 95, root: "/repo" })
  expect(none.ok).toBe(false)
  expect(none.error).toContain("no executable lines")
})

test("coverage rejects malformed reports and a missing test target", () => {
  const core = ["Displaybase/Core/A.swift"]
  const opts = { threshold: 95, root: "/repo" }
  expect(computeCoverage(null, core, opts).ok).toBe(false)
  expect(computeCoverage({ targets: "x" }, core, opts).ok).toBe(false)
  expect(
    computeCoverage({ targets: [{ name: "T.xctest", files: [{ path: "a", coveredLines: 5, executableLines: 1 }] }] }, core, opts).error
  ).toContain("unreadable")
  expect(computeCoverage(xccov([], "Other.app"), core, opts).error).toContain("no .xctest")
})

test("exclusions match by file name and cover Live wrappers", () => {
  expect(exclusionFor("Displaybase/Core/LiveDisplays.swift")?.match).toBe("Live*.swift")
  expect(exclusionFor("Displaybase/Core/DDC.swift")).toBeDefined()
  expect(exclusionFor("Displaybase/Core/DeskController.swift")).toBeUndefined()
  expect(exclusionFor("Displaybase/Core/DDCTests.swift")).toBeUndefined()
})

// scripts with fake tools

function fixture(): string {
  const root = mkdtempSync(join(tmpdir(), "displaybase-ci-"))
  temporary.push(root)
  mkdirSync(join(root, "bin"))
  return root
}

function fake(root: string, name: string, source: string) {
  const path = join(root, "bin", name)
  writeFileSync(path, `#!${process.execPath}\n${source}`)
  chmodSync(path, 0o755)
}

function runScript(root: string, script: string, args: string[], env: Record<string, string>) {
  const r = spawnSync(process.execPath, [resolve(scripts, script), ...args], {
    cwd: root,
    env: { PATH: `${join(root, "bin")}:${process.env.PATH}`, ...env },
    encoding: "utf8",
    timeout: 60_000,
  })
  expect(r.error).toBeUndefined()
  return r
}

const summaryOf = (path: string) => JSON.parse(readFileSync(path, "utf8"))

const fakeSwiftlint = `
const mode = process.env.TOOL_MODE
if (mode === "crash") { console.error("swiftlint crashed"); process.exit(1) }
if (mode === "invalid") { console.log("not json"); process.exit(0) }
if (mode === "findings") { console.log(JSON.stringify([{ file: process.cwd() + "/A.swift", line: 1, rule_id: "force_cast", reason: "r" }])); process.exit(2) }
console.log("[]")
`
const fakePeriphery = `
const mode = process.env.TOOL_MODE
if (mode === "crash") { console.error("build failed"); process.exit(1) }
console.log("[]")
`

function lint(mode: string) {
  const root = fixture()
  fake(root, "swiftlint", fakeSwiftlint)
  fake(root, "periphery", fakePeriphery)
  const r = runScript(root, "lint-report.ts", [], { TOOL_MODE: mode })
  return { r, summary: summaryOf(join(root, "build/lint/summary.json")) }
}

test("lint report passes when both tools are clean", () => {
  const { r, summary } = lint("pass")
  expect(r.status).toBe(0)
  expect(summary.ok).toBe(true)
  expect(summary.results.map((x: { tool: string }) => x.tool)).toEqual(["SwiftLint", "Periphery"])
})

test("lint report fails on findings, malformed output and crashes", () => {
  for (const mode of ["findings", "invalid", "crash"]) {
    const { r, summary } = lint(mode)
    expect(r.status).toBe(1)
    expect(summary.ok).toBe(false)
  }
  expect(lint("findings").summary.results[0].findings[0]).toMatchObject({ file: "A.swift", rule: "force_cast" })
})

test("lint report fails when a tool is not installed", () => {
  const root = fixture()
  fake(root, "swiftlint", fakeSwiftlint)
  const r = runScript(root, "lint-report.ts", [], { TOOL_MODE: "pass", PATH: join(root, "bin") })
  expect(r.status).toBe(1)
  expect(summaryOf(join(root, "build/lint/summary.json")).results[1].ok).toBe(false)
})

const fakeXcrun = `
const [tool, sub] = process.argv.slice(2)
const mode = process.env.TOOL_MODE
if (mode === "crash") { console.error("xccov crashed"); process.exit(1) }
if (tool === "xccov") {
  if (mode === "invalid") { console.log("{not json"); process.exit(0) }
  const covered = mode === "low" ? 10 : 100
  console.log(JSON.stringify({ targets: [{ name: "T.xctest", files: [
    { path: process.cwd() + "/Displaybase/Core/A.swift", coveredLines: covered, executableLines: 100 },
    { path: process.cwd() + "/Displaybase/Core/DDC.swift", coveredLines: 0, executableLines: 50 },
  ] }] }))
} else {
  const failed = mode === "failing" ? 2 : 0
  console.log(JSON.stringify({ passedTests: 5, failedTests: failed, skippedTests: 0, totalTestCount: 5 + failed, result: failed ? "Failed" : "Passed" }))
}
`

function coverage(mode: string) {
  const root = fixture()
  mkdirSync(join(root, "Displaybase/Core"), { recursive: true })
  writeFileSync(join(root, "Displaybase/Core/A.swift"), "")
  writeFileSync(join(root, "Displaybase/Core/DDC.swift"), "")
  fake(root, "xcrun", fakeXcrun)
  const r = runScript(root, "swift-coverage.ts", [], { TOOL_MODE: mode })
  return { r, summary: summaryOf(join(root, "build/coverage/summary.json")) }
}

test("coverage script passes at 100 percent and still lists the excluded file", () => {
  const { r, summary } = coverage("pass")
  expect(r.status).toBe(0)
  expect(summary.ok).toBe(true)
  expect(summary.tests.passed).toBe(5)
  expect(summary.files.find((f: { excluded: boolean }) => f.excluded)).toBeDefined()
  expect(r.stdout).toContain("excluded")
})

test("coverage script fails under the gate, with failing tests, malformed output and a crash", () => {
  for (const mode of ["low", "failing", "invalid", "crash"]) {
    const { r, summary } = coverage(mode)
    expect(r.status).toBe(1)
    expect(summary.ok).toBe(false)
  }
})

const fakeBunx = `
import { mkdirSync, writeFileSync } from "node:fs"
import { join } from "node:path"
const [tool, ...args] = process.argv.slice(2)
const mode = process.env.TOOL_MODE
if (mode === "crash") { console.error("tool crashed"); process.exit(2) }
const bad = mode === "invalid" && !tool.startsWith("jscpd")
if (bad) { console.log("garbage"); process.exit(0) }
const findings = mode === "findings"
if (tool === "next") {
  if (args[0] === "build" && mode === "build-fail") { console.error("build failed"); process.exit(1) }
} else if (tool === "tsc") {
  if (findings) { console.log("src/a.ts(1,1): error TS1: bad"); process.exit(2) }
} else if (tool.startsWith("oxlint")) {
  console.log(JSON.stringify({ diagnostics: findings ? [{ filename: "src/a.ts", code: "x", message: "m", labels: [{ span: { line: 2 } }] }] : [] }))
  process.exit(findings ? 1 : 0)
} else if (tool.startsWith("knip")) {
  console.log(JSON.stringify({ issues: findings ? [{ file: "src/b.ts", exports: [{ name: "n", line: 1 }] }] : [] }))
  process.exit(findings ? 1 : 0)
} else if (tool.startsWith("jscpd")) {
  const out = args[args.indexOf("--output") + 1]
  mkdirSync(out, { recursive: true })
  const pct = findings ? 5 : 0
  writeFileSync(join(out, "jscpd-report.json"), JSON.stringify({ statistics: { total: { percentage: pct, lines: 100, duplicatedLines: pct } }, duplicates: [] }))
  process.exit(findings ? 1 : 0)
}
`

function site(mode: string, withTests = false) {
  const root = fixture()
  mkdirSync(join(root, "site/src"), { recursive: true })
  if (withTests) {
    fake(root, "bun", `console.log(" 3 pass\\n 0 fail"); process.exit(process.env.TOOL_MODE === "test-fail" ? 1 : 0)`)
    writeFileSync(join(root, "site/src/a.test.ts"), "")
  }
  fake(root, "bunx", fakeBunx)
  const r = runScript(root, "site-report.ts", [], { TOOL_MODE: mode })
  return { r, summary: summaryOf(join(root, "build/site/summary.json")) }
}

test("site report passes, with tests skipped when none exist", () => {
  const { r, summary } = site("pass")
  expect(r.status).toBe(0)
  expect(summary.results.map((x: { tool: string }) => x.tool)).toEqual([
    "tsc",
    "oxlint",
    "knip",
    "jscpd",
    "bun test",
    "next build",
  ])
  expect(summary.results.every((x: { ok: boolean }) => x.ok)).toBe(true)
})

test("site report keeps findings from every tool with site-relative paths fixed up", () => {
  const { r, summary } = site("findings")
  expect(r.status).toBe(1)
  const bad = summary.results.filter((x: { ok: boolean }) => !x.ok).map((x: { tool: string }) => x.tool)
  expect(bad).toEqual(["tsc", "oxlint", "knip", "jscpd"])
  expect(summary.results[1].findings[0].file).toBe("site/src/a.ts")
})

test("site report fails closed on garbage output, tool crashes and a failed build", () => {
  for (const mode of ["invalid", "crash", "build-fail"]) {
    const { r, summary } = site(mode)
    expect(r.status).toBe(1)
    expect(summary.ok).toBe(false)
  }
  const crashed = site("crash").summary.results
  expect(crashed.filter((x: { tool: string; ok: boolean }) => x.tool !== "bun test").every((x: { ok: boolean }) => !x.ok)).toBe(true)
})

test("site report runs bun test when tests exist and fails when they do", () => {
  expect(site("pass", true).summary.results[4]).toMatchObject({ ok: true, detail: "3 pass, 0 fail" })
  const failing = site("test-fail", true)
  expect(failing.r.status).toBe(1)
  expect(failing.summary.results[4].ok).toBe(false)
})

// comment

async function comment(root: string, existing: { id: number; body: string }[][]) {
  const calls: { method: string; url: string; body?: string }[] = []
  const server = Bun.serve({
    port: 0,
    async fetch(req) {
      const url = new URL(req.url)
      const body = req.method === "GET" ? undefined : await req.text()
      calls.push({ method: req.method, url: url.pathname + url.search, body })
      if (req.method === "GET") {
        const page = Number(url.searchParams.get("page"))
        return Response.json(existing[page - 1] ?? [])
      }
      return Response.json({ id: 1 })
    },
  })
  try {
    const { upsertPrComment } = await import("../pr-comment")
    await upsertPrComment("<!-- m -->", "<!-- m -->\nbody", {
      REPO: "Rad-Soft/displaybase",
      PR_NUMBER: "7",
      GH_TOKEN: "t",
      GITHUB_API_URL: `http://localhost:${server.port}`,
    })
  } finally {
    server.stop(true)
  }
  return calls
}

test("the comment is updated in place when the marker is on a later page", async () => {
  const full = Array.from({ length: 100 }, (_, i) => ({ id: i + 1, body: "other" }))
  const calls = await comment(fixture(), [full, [{ id: 500, body: "<!-- m --> old" }]])
  expect(calls.map((c) => c.method)).toEqual(["GET", "GET", "PATCH"])
  expect(calls[2]!.url).toBe("/repos/Rad-Soft/displaybase/issues/comments/500")
})

test("one comment is created when no page has the marker", async () => {
  const calls = await comment(fixture(), [[{ id: 1, body: "other" }]])
  expect(calls.map((c) => c.method)).toEqual(["GET", "POST"])
  expect(JSON.parse(calls[1]!.body!).body).toContain("body")
})

test("the comment builder marks missing reports as incomplete and red", async () => {
  const { buildComment, MARKER } = await import("../ci-comment")
  const root = fixture()
  const missing = buildComment(root)
  expect(missing.complete).toBe(false)
  expect(missing.ok).toBe(false)
  expect(missing.body.startsWith(MARKER)).toBe(true)
  expect(missing.body).toContain("no report")

  const put = (name: string, data: unknown) => {
    mkdirSync(join(root, name), { recursive: true })
    writeFileSync(join(root, name, "summary.json"), JSON.stringify(data))
  }
  const ok = (tool: string, category: string) => ({ tool, category, ok: true, count: 0, detail: "0 findings", findings: [] })
  put("lint", { name: "lint", ok: true, results: [ok("SwiftLint", "smell"), ok("Periphery", "dead-code")] })
  put("site", {
    name: "site",
    ok: true,
    results: ["tsc", "oxlint", "knip", "jscpd", "bun test", "next build"].map((t) => ok(t, "smell")),
  })
  put("coverage", {
    name: "app",
    threshold: 95,
    ok: false,
    tests: { passed: 3, failed: 0, skipped: 0, total: 3, result: "Passed" },
    lines: 50,
    covered: 5,
    executable: 10,
    files: [
      { file: "Displaybase/Core/A.swift", covered: 5, executable: 10, lines: 50, excluded: false },
      { file: "Displaybase/Core/DDC.swift", covered: 0, executable: 9, lines: 0, excluded: true, reason: "needs a monitor" },
    ],
  })
  const built = buildComment(root)
  expect(built.complete).toBe(true)
  expect(built.ok).toBe(false)
  expect(built.body).toContain("Displaybase/Core/A.swift")
  expect(built.body).toContain("needs a monitor")
})
