import {
  crashDetail,
  crashed,
  fromFindings,
  parseJson,
  plural,
  toRelative,
  type Finding,
  type RunResult,
  type ToolResult,
} from "./report"

const isObject = (x: unknown): x is Record<string, any> =>
  typeof x === "object" && x !== null && !Array.isArray(x)

const failed = (r: RunResult) => r.error !== null || r.signal !== null

export function parseSwiftlint(r: RunResult, root?: string): ToolResult {
  const data = parseJson(r.stdout)
  if (!Array.isArray(data)) return crashed("SwiftLint", "smell", crashDetail(r))
  if (failed(r) || (data.length === 0 && r.status !== 0))
    return crashed("SwiftLint", "smell", crashDetail(r))
  const findings: Finding[] = []
  for (const d of data) {
    if (!isObject(d) || typeof d.file !== "string")
      return crashed("SwiftLint", "smell", "unreadable violation in the report")
    findings.push({
      file: toRelative(d.file, root),
      line: typeof d.line === "number" ? d.line : undefined,
      rule: String(d.rule_id ?? "unknown"),
      message: String(d.reason ?? ""),
    })
  }
  return fromFindings("SwiftLint", "smell", findings)
}

// @_silgen_name stubs have no body, so Periphery calls every parameter unused
export function silgenStub(lines: string[], line: number): boolean {
  return (lines[line - 2] ?? "").trimStart().startsWith("@_silgen_name")
}

export function parsePeriphery(
  r: RunResult,
  readLines: (file: string) => string[] = () => [],
  root?: string
): ToolResult {
  const data = parseJson(r.stdout)
  if (!Array.isArray(data))
    return crashed("Periphery", "dead-code", crashDetail(r))
  if (failed(r) || (data.length === 0 && r.status !== 0))
    return crashed("Periphery", "dead-code", crashDetail(r))
  const findings: Finding[] = []
  for (const d of data) {
    if (!isObject(d) || typeof d.location !== "string")
      return crashed("Periphery", "dead-code", "unreadable result in the report")
    const m = d.location.match(/^(.*):(\d+):\d+$/)
    if (!m) return crashed("Periphery", "dead-code", `bad location ${d.location}`)
    const file = toRelative(m[1]!, root)
    const line = Number(m[2])
    if (d.kind === "var.parameter" && silgenStub(readLines(file), line)) continue
    const hints = Array.isArray(d.hints) ? d.hints.join(", ") : "unused"
    findings.push({
      file,
      line,
      rule: hints,
      message: `${d.kind} ${d.name}`,
    })
  }
  return fromFindings("Periphery", "dead-code", findings)
}

const TSC_LINE = /^(.+?)\((\d+),\d+\): error (TS\d+): (.*)$/

export function parseTsc(r: RunResult): ToolResult {
  if (failed(r)) return crashed("tsc", "smell", crashDetail(r))
  const findings: Finding[] = []
  for (const line of r.stdout.split("\n")) {
    const m = line.match(TSC_LINE)
    if (m)
      findings.push({
        file: m[1]!,
        line: Number(m[2]),
        rule: m[3]!,
        message: m[4]!,
      })
  }
  if (r.status !== 0 && findings.length === 0)
    return crashed("tsc", "smell", crashDetail(r))
  if (r.status === 0 && findings.length > 0)
    return crashed("tsc", "smell", "exit 0 with errors in the output")
  return fromFindings("tsc", "smell", findings)
}

export function parseOxlint(r: RunResult): ToolResult {
  const out = parseJson(r.stdout)
  const diagnostics = isObject(out) && Array.isArray(out.diagnostics) ? out.diagnostics : null
  if (diagnostics === null || failed(r))
    return crashed("oxlint", "smell", crashDetail(r))
  const findings: Finding[] = []
  for (const d of diagnostics) {
    if (!isObject(d) || typeof d.filename !== "string")
      return crashed("oxlint", "smell", "unreadable diagnostic in the report")
    findings.push({
      file: d.filename,
      line: d.labels?.[0]?.span?.line,
      rule: String(d.code ?? "oxlint"),
      message: String(d.message ?? ""),
    })
  }
  if (r.status !== 0 && findings.length === 0)
    return crashed("oxlint", "smell", crashDetail(r))
  return fromFindings("oxlint", "smell", findings)
}

export function parseKnip(r: RunResult): ToolResult {
  const out = parseJson(r.stdout)
  if (!isObject(out) || !Array.isArray(out.issues) || failed(r))
    return crashed("knip", "dead-code", crashDetail(r))
  const findings: Finding[] = []
  if (Array.isArray(out.files))
    for (const f of out.files)
      findings.push({ file: String(f), rule: "unused file", message: "nothing imports this file" })
  for (const issue of out.issues) {
    if (!isObject(issue) || typeof issue.file !== "string")
      return crashed("knip", "dead-code", "unreadable issue in the report")
    for (const [kind, items] of Object.entries(issue)) {
      if (kind === "file" || !Array.isArray(items)) continue
      for (const item of items) {
        const name = isObject(item) ? item.name : item
        findings.push({
          file: issue.file,
          line: isObject(item) && typeof item.line === "number" ? item.line : undefined,
          rule: kind === "files" ? "unused file" : kind,
          message: kind === "files" ? "nothing imports this file" : String(name),
        })
      }
    }
  }
  if (r.status !== 0 && findings.length === 0)
    return crashed("knip", "dead-code", crashDetail(r))
  return fromFindings("knip", "dead-code", findings)
}

export function parseJscpd(
  r: RunResult,
  reportText: string | null,
  max: number,
  root?: string
): ToolResult {
  const report = reportText === null ? null : parseJson(reportText)
  const total = isObject(report) && isObject(report.statistics) ? report.statistics.total : null
  if (
    !isObject(total) ||
    typeof total.percentage !== "number" ||
    !Array.isArray((report as Record<string, unknown>).duplicates)
  )
    return crashed("jscpd", "duplication", `no readable report (${crashDetail(r)})`)
  if (failed(r)) return crashed("jscpd", "duplication", crashDetail(r))
  const duplicates = (report as { duplicates: Record<string, any>[] }).duplicates
  const findings: Finding[] = duplicates.map((d) => ({
    file: toRelative(String(d.firstFile?.name), root),
    line: d.firstFile?.startLoc?.line,
    rule: `${d.lines} lines`,
    message: `also at ${toRelative(String(d.secondFile?.name), root)}:${d.secondFile?.startLoc?.line}`,
  }))
  const within = total.percentage <= max
  // jscpd exits 1 only for the threshold; any other nonzero exit is a crash
  if (r.status !== 0 && within) return crashed("jscpd", "duplication", crashDetail(r))
  return {
    tool: "jscpd",
    category: "duplication",
    ok: within && r.status === 0,
    count: findings.length,
    detail: `${total.percentage.toFixed(2)}% of lines duplicated (${total.duplicatedLines} of ${total.lines}), ${plural(findings.length, "clone")}, gate ${max}%`,
    findings,
  }
}
