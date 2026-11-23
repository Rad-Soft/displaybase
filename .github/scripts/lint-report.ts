import { readFileSync } from "node:fs"
import { parsePeriphery, parseSwiftlint } from "./parsers"
import { arg, publish, resultsTable, run, writeSummary } from "./report"

const out = arg("out", "build/lint")

const readLines = (file: string) => {
  try {
    return readFileSync(file, "utf8").split("\n")
  } catch {
    return []
  }
}

const swiftlint = parseSwiftlint(
  run("swiftlint", ["lint", "--strict", "--quiet", "--reporter", "json"])
)

const periphery = parsePeriphery(
  run("periphery", [
    "scan",
    "--format",
    "json",
    "--quiet",
  ]),
  readLines
)

const summary = writeSummary(out, "lint", [swiftlint, periphery])
publish(resultsTable("Swift lint and dead code", summary.results))
process.exit(summary.ok ? 0 : 1)
