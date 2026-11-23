import { existsSync, readFileSync } from "node:fs"
import { join } from "node:path"
import type { CoverageSummary } from "./coverage"
import { upsertPrComment } from "./pr-comment"
import { cell, plural, where, type Summary, type ToolResult } from "./report"

export const MARKER = "<!-- displaybase-ci -->"

const isObject = (x: unknown): x is Record<string, unknown> =>
  typeof x === "object" && x !== null && !Array.isArray(x)

function load<T>(root: string, name: string, valid: (x: unknown) => boolean): T | null {
  const path = join(root, name, "summary.json")
  if (!existsSync(path)) return null
  try {
    const data: unknown = JSON.parse(readFileSync(path, "utf8"))
    return valid(data) ? (data as T) : null
  } catch {
    return null
  }
}

const isResults = (x: unknown) =>
  isObject(x) && typeof x.ok === "boolean" && Array.isArray(x.results)
const isCoverage = (x: unknown) =>
  isObject(x) &&
  typeof x.ok === "boolean" &&
  typeof x.threshold === "number" &&
  typeof x.lines === "number" &&
  Array.isArray(x.files)

const icon = (ok: boolean) => (ok ? "✅" : "❌")
const MISSING = "❌ no report, the job did not finish"

function toolRows(results: ToolResult[] | null, tools: string[]): string {
  let md = ""
  for (const tool of tools) {
    const r = results?.find((x) => x.tool === tool)
    md += r
      ? `| ${r.tool} | ${cell(r.detail)} | ${icon(r.ok)} |\n`
      : `| ${tool} | ${MISSING} | ❌ |\n`
  }
  return md
}

function findings(results: ToolResult[], limit = 25): string {
  let md = ""
  for (const r of results) {
    if (r.ok || r.findings.length === 0) continue
    md += `\n<details><summary><code>${r.tool}</code>: ${plural(r.findings.length, "finding")}</summary>\n\n| file | rule | message |\n|---|---|---|\n`
    for (const f of r.findings.slice(0, limit))
      md += `| \`${where(f)}\` | ${cell(f.rule)} | ${cell(f.message)} |\n`
    if (r.findings.length > limit) md += `| … | ${r.findings.length - limit} more | |\n`
    md += `\n</details>\n`
  }
  return md
}

export function buildComment(root: string): { body: string; complete: boolean; ok: boolean } {
  const lint = load<Summary>(root, "lint", isResults)
  const site = load<Summary>(root, "site", isResults)
  const cov = load<CoverageSummary>(root, "coverage", isCoverage)
  const complete = lint !== null && site !== null && cov !== null
  const ok = complete && lint.ok && site.ok && cov.ok

  let body = `${MARKER}\n## ${icon(ok)} CI report\n`

  body += `\n### Tests\n\n| suite | result | |\n|---|---|:---:|\n`
  if (cov?.tests) {
    const t = cov.tests
    body += `| app (Swift Testing) | ${t.passed} passed, ${t.failed} failed, ${t.skipped} skipped of ${t.total} | ${icon(t.failed === 0 && t.result === "Passed")} |\n`
  } else body += `| app (Swift Testing) | ${cov ? "test summary unreadable" : MISSING} | ❌ |\n`
  body += toolRows(site?.results ?? null, ["bun test"])

  body += `\n### Coverage\n\n`
  if (cov) {
    const under = cov.files
      .filter((f) => !f.excluded && f.executable > 0 && f.lines < cov.threshold)
      .sort((a, b) => a.lines - b.lines)
    const excluded = cov.files.filter((f) => f.excluded)
    body += `${icon(cov.ok)} Lines **${cov.lines.toFixed(1)}%** (${cov.covered}/${cov.executable}) in Displaybase/Core, gate ${cov.threshold}%.`
    if (cov.error) body += ` ${cell(cov.error)}.`
    body += `\n`
    if (under.length) {
      body += `\n<details><summary>${plural(under.length, "file")} under the ${cov.threshold}% gate</summary>\n\n| file | lines | covered |\n|---|---:|---:|\n`
      for (const f of under)
        body += `| \`${f.file}\` | ${f.lines.toFixed(1)}% | ${f.covered}/${f.executable} |\n`
      body += `\n</details>\n`
    }
    if (excluded.length) {
      body += `\n<details><summary>${plural(excluded.length, "file")} excluded, they need hardware</summary>\n\n| file | lines | why |\n|---|---:|---|\n`
      for (const f of excluded)
        body += `| \`${f.file}\` | ${f.lines.toFixed(1)}% | ${cell(f.reason ?? "")} |\n`
      body += `\n</details>\n`
    }
  } else body += `${MISSING}\n`

  const groups: [string, ToolResult[] | null, string[]][] = [
    ["Code smells by tool", [...(lint?.results ?? []), ...(site?.results ?? [])], ["SwiftLint", "tsc", "oxlint"]],
    ["Dead code", [...(lint?.results ?? []), ...(site?.results ?? [])], ["Periphery", "knip"]],
    ["Duplication", site?.results ?? null, ["jscpd"]],
    ["Build", site?.results ?? null, ["next build"]],
  ]
  for (const [title, results, tools] of groups) {
    body += `\n### ${title}\n\n| tool | result | |\n|---|---|:---:|\n`
    body += toolRows(results, tools)
    body += findings((results ?? []).filter((r) => tools.includes(r.tool)))
  }

  body += `\n<sub>Gates: SwiftLint strict with no violations, no Periphery, oxlint, tsc or knip findings, duplication at most 3% of lines, app coverage at least ${cov?.threshold ?? 95}% of Core lines. Hardware-bound files are excluded and listed above.</sub>\n`
  return { body, complete, ok }
}

if (import.meta.main) {
  const root = process.env.SUMMARIES_DIR ?? "ci-summaries"
  const { body, complete } = buildComment(root)
  await upsertPrComment(MARKER, body)
  // the jobs fail on their own findings; this one only fails when a report is missing
  if (!complete) {
    console.error("a summary is missing, so the report is incomplete")
    process.exit(1)
  }
}
