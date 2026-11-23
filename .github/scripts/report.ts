import { spawnSync } from "node:child_process"
import { appendFileSync, mkdirSync, writeFileSync } from "node:fs"
import { join } from "node:path"

export type Finding = {
  file: string
  line?: number
  rule: string
  message: string
}

export type Category = "smell" | "dead-code" | "duplication" | "tests" | "build"

export type ToolResult = {
  tool: string
  category: Category
  ok: boolean
  count: number
  detail: string
  findings: Finding[]
}

export type Summary = { name: string; ok: boolean; results: ToolResult[] }

export type RunResult = {
  status: number | null
  signal: string | null
  stdout: string
  stderr: string
  error: string | null
}

export function run(
  cmd: string,
  args: string[],
  options: { cwd?: string; timeoutMs?: number } = {}
): RunResult {
  const r = spawnSync(cmd, args, {
    cwd: options.cwd,
    encoding: "utf8",
    maxBuffer: 256 * 1024 * 1024,
    timeout: options.timeoutMs ?? 30 * 60 * 1000,
  })
  return {
    status: r.status,
    signal: r.signal,
    stdout: r.stdout ?? "",
    stderr: r.stderr ?? "",
    error: r.error ? r.error.message : null,
  }
}

export const plural = (n: number, word: string) =>
  `${n} ${word}${n === 1 ? "" : "s"}`

export const where = (f: Finding) => (f.line ? `${f.file}:${f.line}` : f.file)

export const cell = (text: string) =>
  text.replace(/\|/g, "\\|").replace(/\n/g, " ")

export function crashDetail(r: RunResult): string {
  const why = r.error ?? (r.signal ? `signal ${r.signal}` : `exit ${r.status}`)
  const tail = (r.stderr.trim() || r.stdout.trim()).slice(-300)
  return tail ? `${why}: ${tail}` : why
}

export function parseJson(text: string): unknown {
  try {
    return JSON.parse(text)
  } catch {
    return null
  }
}

export function toRelative(file: string, root = process.cwd()): string {
  return file.startsWith(`${root}/`) ? file.slice(root.length + 1) : file
}

// a tool that could not run or printed something unreadable is red, never green
export function crashed(
  tool: string,
  category: Category,
  why: string
): ToolResult {
  return {
    tool,
    category,
    ok: false,
    count: 0,
    detail: `tool failed: ${why}`,
    findings: [],
  }
}

export function fromFindings(
  tool: string,
  category: Category,
  findings: Finding[],
  detail?: string
): ToolResult {
  return {
    tool,
    category,
    ok: findings.length === 0,
    count: findings.length,
    detail: detail ?? plural(findings.length, "finding"),
    findings,
  }
}

export function findingsTable(results: ToolResult[], limit = 40): string {
  let md = ""
  for (const r of results) {
    if (r.ok || r.findings.length === 0) continue
    md += `\n<details><summary><code>${r.tool}</code>: ${plural(r.findings.length, "finding")}</summary>\n\n| file | rule | message |\n|---|---|---|\n`
    for (const f of r.findings.slice(0, limit))
      md += `| \`${where(f)}\` | ${cell(f.rule)} | ${cell(f.message)} |\n`
    if (r.findings.length > limit)
      md += `| … | ${r.findings.length - limit} more | |\n`
    md += `\n</details>\n`
  }
  return md
}

export function resultsTable(title: string, results: ToolResult[]): string {
  const ok = results.every((r) => r.ok)
  let md = `## ${ok ? "✅" : "❌"} ${title}\n\n| tool | result | |\n|---|---|:---:|\n`
  for (const r of results)
    md += `| ${r.tool} | ${cell(r.detail)} | ${r.ok ? "✅" : "❌"} |\n`
  return md + findingsTable(results)
}

export function writeSummary(
  dir: string,
  name: string,
  results: ToolResult[]
): Summary {
  mkdirSync(dir, { recursive: true })
  const summary = { name, ok: results.every((r) => r.ok), results }
  writeFileSync(join(dir, "summary.json"), JSON.stringify(summary, null, 2))
  return summary
}

export function publish(md: string): void {
  console.log(md)
  if (process.env.GITHUB_STEP_SUMMARY)
    appendFileSync(process.env.GITHUB_STEP_SUMMARY, md)
}

export function arg(name: string, fallback: string): string {
  const i = process.argv.indexOf(`--${name}`)
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1]! : fallback
}
