import { exclusionFor, type Exclusion } from "./coverage-exclusions"
import { cell, toRelative } from "./report"

export type FileCoverage = {
  file: string
  covered: number
  executable: number
  lines: number
  excluded: boolean
  reason?: string
  // in the project but absent from the report, so it has no executable lines
  missing?: boolean
}

export type TestCounts = {
  passed: number
  failed: number
  skipped: number
  total: number
  result: string
}

export type CoverageSummary = {
  name: "app"
  threshold: number
  ok: boolean
  error?: string
  tests: TestCounts | null
  lines: number
  covered: number
  executable: number
  files: FileCoverage[]
}

type XccovFile = {
  path: string
  coveredLines: number
  executableLines: number
}
type XccovTarget = { name: string; files: XccovFile[] }

const pct = (covered: number, executable: number) =>
  executable === 0 ? 100 : (100 * covered) / executable

const isObject = (x: unknown): x is Record<string, unknown> =>
  typeof x === "object" && x !== null && !Array.isArray(x)

const count = (x: unknown): number | null =>
  typeof x === "number" && Number.isFinite(x) && x >= 0 ? x : null

export function parseTargets(data: unknown): XccovTarget[] | null {
  if (!isObject(data) || !Array.isArray(data.targets)) return null
  const targets: XccovTarget[] = []
  for (const t of data.targets) {
    if (!isObject(t) || typeof t.name !== "string" || !Array.isArray(t.files))
      return null
    const files: XccovFile[] = []
    for (const f of t.files) {
      if (!isObject(f) || typeof f.path !== "string") return null
      const covered = count(f.coveredLines)
      const executable = count(f.executableLines)
      if (covered === null || executable === null || covered > executable)
        return null
      files.push({ path: f.path, coveredLines: covered, executableLines: executable })
    }
    targets.push({ name: t.name, files })
  }
  return targets
}

export function parseTests(data: unknown): TestCounts | null {
  if (!isObject(data)) return null
  const passed = count(data.passedTests)
  const failed = count(data.failedTests)
  const skipped = count(data.skippedTests)
  const total = count(data.totalTestCount)
  if (
    passed === null ||
    failed === null ||
    skipped === null ||
    total === null ||
    typeof data.result !== "string"
  )
    return null
  return { passed, failed, skipped, total, result: data.result }
}

// the tests compile Core themselves, so the .xctest target holds its coverage;
// the app target is never run and always reads zero
export function computeCoverage(
  data: unknown,
  coreFiles: string[],
  options: {
    threshold: number
    root?: string
    exclusionList?: Exclusion[]
  }
): { ok: boolean; error?: string; files: FileCoverage[]; lines: number; covered: number; executable: number } {
  const empty = { ok: false, files: [], lines: 0, covered: 0, executable: 0 }
  const targets = parseTargets(data)
  if (!targets) return { ...empty, error: "unreadable xccov report" }
  const tests = targets.filter((t) => t.name.endsWith(".xctest"))
  if (tests.length === 0) return { ...empty, error: "no .xctest target in the coverage report" }
  const reported = tests.flatMap((t) => t.files)

  const files: FileCoverage[] = coreFiles.map((file) => {
    const entry = reported.find(
      (r) => toRelative(r.path, options.root) === file
    )
    const exclusion = exclusionFor(file, options.exclusionList)
    const covered = entry?.coveredLines ?? 0
    const executable = entry?.executableLines ?? 0
    return {
      file,
      covered,
      executable,
      lines: pct(covered, executable),
      excluded: exclusion !== undefined,
      reason: exclusion?.reason,
      missing: entry === undefined,
    }
  })

  const gated = files.filter((f) => !f.excluded)
  const covered = gated.reduce((n, f) => n + f.covered, 0)
  const executable = gated.reduce((n, f) => n + f.executable, 0)
  if (executable === 0)
    return { ...empty, files, error: "no executable lines measured in Core" }
  return {
    ok: covered * 100 >= options.threshold * executable,
    files,
    lines: pct(covered, executable),
    covered,
    executable,
  }
}

export function renderCoverage(s: CoverageSummary): string {
  const f1 = (n: number) => `${n.toFixed(1)}%`
  const gated = s.files.filter((f) => !f.excluded)
  const below = gated
    .filter((f) => f.executable > 0 && f.lines < s.threshold)
    .sort((a, b) => a.lines - b.lines)
  const excluded = s.files.filter((f) => f.excluded)
  let md = `## ${s.ok ? "✅" : "❌"} App coverage\n\n`
  if (s.error) md += `**Failed:** ${cell(s.error)}\n\n`
  if (s.tests)
    md += `Tests: ${s.tests.passed} passed, ${s.tests.failed} failed, ${s.tests.skipped} skipped (${s.tests.result}).\n\n`
  md += `Lines **${f1(s.lines)}** (${s.covered}/${s.executable}) over ${gated.length} files in Displaybase/Core, gate ${s.threshold}%.\n`
  if (below.length) {
    md += `\n<details><summary>${below.length} file${below.length === 1 ? "" : "s"} under ${s.threshold}%</summary>\n\n| file | lines | covered |\n|---|---:|---:|\n`
    for (const f of below)
      md += `| \`${f.file}\` | ${f1(f.lines)} | ${f.covered}/${f.executable} |\n`
    md += `\n</details>\n`
  }
  if (excluded.length) {
    md += `\n<details><summary>${excluded.length} excluded file${excluded.length === 1 ? "" : "s"} (need hardware)</summary>\n\n| file | lines | why |\n|---|---:|---|\n`
    for (const f of excluded)
      md += `| \`${f.file}\` | ${f1(f.lines)} | ${cell(f.reason ?? "")} |\n`
    md += `\n</details>\n`
  }
  return md
}
