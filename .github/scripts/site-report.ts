import { existsSync, mkdirSync, readdirSync, readFileSync } from "node:fs"
import { join } from "node:path"
import {
  parseJscpd,
  parseKnip,
  parseOxlint,
  parseTsc,
} from "./parsers"
import {
  arg,
  crashDetail,
  crashed,
  fromFindings,
  publish,
  resultsTable,
  run,
  writeSummary,
  type ToolResult,
} from "./report"

// pinned here so site/package.json stays untouched
const OXLINT = "oxlint@1.91.0"
const KNIP = "knip@6.44.1"
const JSCPD = "jscpd@5.4.2"

const out = arg("out", "build/site")
const site = arg("site", "site")
const maxDuplication = Number(arg("max-duplication", "3"))
const swiftDirs = ["Displaybase", "DisplaybaseTests"]
process.env.NEXT_TELEMETRY_DISABLED = "1"

function typecheck(): ToolResult {
  const gen = run("bunx", ["next", "typegen"], { cwd: site })
  if (gen.status !== 0) return crashed("tsc", "smell", `next typegen: ${crashDetail(gen)}`)
  return parseTsc(run("bunx", ["tsc", "--noEmit", "--pretty", "false"], { cwd: site }))
}

function duplication(): ToolResult {
  const dir = join(out, "jscpd")
  mkdirSync(dir, { recursive: true })
  const paths = [join(site, "src"), ...swiftDirs].filter(existsSync)
  const r = run("bunx", [
    JSCPD,
    ...paths,
    "--format",
    "typescript,tsx,swift",
    "--reporters",
    "json",
    "--output",
    dir,
    "--threshold",
    String(maxDuplication),
    "--absolute",
    "--silent",
  ])
  const report = join(dir, "jscpd-report.json")
  return parseJscpd(r, existsSync(report) ? readFileSync(report, "utf8") : null, maxDuplication)
}

function testFiles(dir: string): string[] {
  if (!existsSync(dir)) return []
  return readdirSync(dir, { recursive: true })
    .map(String)
    .filter((f) => !/(^|\/)(node_modules|\.next)\//.test(f))
    .filter((f) => /\.(test|spec)\.[cm]?[jt]sx?$/.test(f))
}

function tests(): ToolResult {
  if (testFiles(site).length === 0)
    return { tool: "bun test", category: "tests", ok: true, count: 0, detail: "no site tests yet", findings: [] }
  const r = run("bun", ["test", "--coverage"], { cwd: site })
  const text = r.stdout + r.stderr
  const pass = text.match(/^\s*(\d+) pass$/m)?.[1]
  const fail = text.match(/^\s*(\d+) fail$/m)?.[1]
  if (r.error !== null || r.signal !== null || pass === undefined)
    return crashed("bun test", "tests", crashDetail(r))
  const ok = r.status === 0 && fail === "0"
  return {
    tool: "bun test",
    category: "tests",
    ok,
    count: Number(fail ?? 0),
    detail: `${pass} pass, ${fail ?? "?"} fail`,
    findings: [],
  }
}

function build(): ToolResult {
  const r = run("bunx", ["next", "build"], { cwd: site })
  if (r.status === 0) return fromFindings("next build", "build", [], "built")
  return crashed("next build", "build", crashDetail(r))
}

// these tools report paths relative to the site folder
const fromSite = (r: ToolResult): ToolResult => ({
  ...r,
  findings: r.findings.map((f) => ({ ...f, file: join(site, f.file) })),
})

const results = [
  fromSite(typecheck()),
  fromSite(parseOxlint(run("bunx", [OXLINT, "--format", "json"], { cwd: site }))),
  fromSite(
    parseKnip(run("bunx", [KNIP, "--reporter", "json", "--no-progress"], { cwd: site }))
  ),
  duplication(),
  tests(),
  build(),
]
const summary = writeSummary(out, "site", results)
publish(resultsTable("Site checks", summary.results))
process.exit(summary.ok ? 0 : 1)
