// files in Displaybase/Core that cannot run without hardware or a real session.
// they stay in the report so nothing is hidden. add a file here only with a reason.
export type Exclusion = { match: string; reason: string }

export const exclusions: Exclusion[] = [
  { match: "DDC.swift", reason: "talks to real monitors over IOAVService I2C" },
  {
    match: "DisplayLayout.swift",
    reason: "reconfigures the real displays through CoreGraphics",
  },
  { match: "Rotation.swift", reason: "rotates the real displays" },
  {
    match: "USBWatcher.swift",
    reason: "needs IOKit USB events from a real device",
  },
  {
    match: "WindowKeeper.swift",
    reason: "moves other apps' windows through Accessibility",
  },
  {
    match: "RemoteComputer.swift",
    reason: "runs ssh against the other computer",
  },
  {
    match: "Hotkey.swift",
    reason: "registers a system-wide shortcut with Carbon",
  },
  {
    match: "Notifier.swift",
    reason: "needs the app bundle and notification permission",
  },
  { match: "Live*.swift", reason: "live wrappers around the hardware" },
]

const toRegExp = (glob: string) =>
  new RegExp(
    `^${glob.replace(/[.+^${}()|[\]\\]/g, "\\$&").replace(/\*/g, "[^/]*")}$`
  )

export function exclusionFor(
  file: string,
  list: Exclusion[] = exclusions
): Exclusion | undefined {
  const name = file.split("/").pop() ?? file
  return list.find((e) => toRegExp(e.match).test(name))
}
