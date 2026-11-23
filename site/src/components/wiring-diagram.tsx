import type { Desk } from "./wiring";

type Owner = "mac" | "pc";

const nodes = [
  { id: "mac", label: "MacBook", x: 60, y: 60, w: 190, h: 96 },
  { id: "pc", label: "Gaming PC", x: 60, y: 324, w: 190, h: 96 },
  { id: "switch", label: "USB switch", x: 480, y: 192, w: 180, h: 96 },
  { id: "side", label: "27-inch", x: 930, y: 40, w: 110, h: 190 },
  { id: "main", label: "32-inch", x: 1080, y: 250, w: 270, h: 160 },
] as const;

const cables: { id: string; path: string; port: string; at: [number, number]; owner: Owner; live: Desk[] }[] = [
  { id: "mac-side", path: "M250 84 H930", port: "Thunderbolt", at: [590, 74], owner: "mac", live: ["mac", "pc"] },
  { id: "mac-main", path: "M250 120 H1215 V250", port: "Thunderbolt", at: [760, 110], owner: "mac", live: ["mac"] },
  { id: "pc-side", path: "M250 354 H985 V230", port: "DisplayPort", at: [760, 344], owner: "pc", live: ["both"] },
  { id: "pc-main", path: "M250 392 H1080", port: "DisplayPort", at: [590, 414], owner: "pc", live: ["pc", "both"] },
  { id: "usb-mac", path: "M155 156 V222 H480", port: "USB", at: [300, 212], owner: "mac", live: ["mac"] },
  { id: "usb-pc", path: "M155 324 V258 H480", port: "USB", at: [300, 278], owner: "pc", live: ["pc", "both"] },
];

const ink: Record<Owner, string> = { mac: "var(--sky)", pc: "var(--clay)" };

export function WiringDiagram({ desk }: { desk: Desk }) {
  function owner(id: string): Owner {
    if (id === "mac") return "mac";
    if (id === "pc") return "pc";
    if (id === "side") return desk === "both" ? "pc" : "mac";
    return desk === "mac" ? "mac" : "pc";
  }

  const sorted = [...cables].sort((a, b) => Number(a.live.includes(desk)) - Number(b.live.includes(desk)));

  return (
    <svg viewBox="0 0 1410 480" className="block w-full min-w-[860px]" role="img" aria-label={`Wiring: the 27-inch screen is on the ${owner("side") === "mac" ? "Mac" : "PC"} and the 32-inch screen is on the ${owner("main") === "mac" ? "Mac" : "PC"}`}>
      {sorted.map((cable) => {
        const live = cable.live.includes(desk);
        return (
          <g key={cable.id} className="transition-opacity duration-300" opacity={live ? 1 : 0.8}>
            <path d={cable.path} fill="none" stroke={live ? ink[cable.owner] : "var(--cable)"} strokeWidth={live ? 2.5 : 1.5} strokeDasharray={live ? "14 6" : "2 8"} className={live ? "flow" : ""} />
            <text x={cable.at[0]} y={cable.at[1]} textAnchor="middle" fontSize="13" fill={live ? ink[cable.owner] : "var(--soft)"} className="font-mono">
              {cable.port}
            </text>
          </g>
        );
      })}
      {nodes.map(({ id, label, x, y, w, h }) => {
        const color = ink[owner(id)];
        return (
          <g key={id}>
            <rect x={x} y={y} width={w} height={h} fill="var(--page)" stroke={color} strokeWidth="1.5" className="transition-[stroke] duration-300" />
            <rect x={x} y={y} width={w} height={h} fill={color} opacity={id === "main" || id === "side" ? 0.9 : 0.08} className="transition-[fill] duration-300" />
            {[
              [x, y],
              [x + w, y],
              [x, y + h],
              [x + w, y + h],
            ].map(([cx, cy]) => (
              <rect key={`${cx}-${cy}`} x={cx - 4} y={cy - 4} width="8" height="8" fill="var(--page)" stroke={color} strokeWidth="1.5" className="transition-[stroke] duration-300" />
            ))}
            <text x={x + w / 2} y={y + h / 2 + 5} textAnchor="middle" fontSize="15" fontWeight="500" fill={id === "main" || id === "side" ? "var(--deep)" : "var(--ink)"} className="font-mono">
              {label}
            </text>
          </g>
        );
      })}
    </svg>
  );
}
