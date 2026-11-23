const asks = [
  { name: "Accessibility", when: "Optional", why: "Puts your windows back where they were", without: "Windows stay where macOS leaves them" },
  { name: "Notifications", when: "Optional", why: "Tells you if your USB switch goes missing", without: "The menu still shows it" },
  { name: "Local network", when: "Only with SSH", why: "Checks on your other computer", without: "Hand-overs go unconfirmed" },
  { name: "Open at login", when: "Optional", why: "So it's there when you sit down", without: "You open it yourself" },
];

export function Permissions() {
  return (
    <section id="permissions" className="border-t border-line">
      <div className="grid gap-10 px-5 py-16 md:px-10 md:py-24 lg:grid-cols-[7fr_5fr] lg:items-end">
        <h2 className="text-5xl leading-[0.95] font-bold tracking-[-0.025em] md:text-7xl">Four permissions. All yours to refuse.</h2>
        <p className="max-w-[46ch] text-lg leading-relaxed text-soft">
          It never records your screen or what you type. There&apos;s no account and no analytics. Apart from your own computer over SSH, the only thing it contacts is its update feed.
        </p>
      </div>
      <div className="overflow-x-auto border-t border-line">
        <table className="w-full min-w-[52rem] text-left">
          <thead className="font-mono text-xs text-soft">
            <tr className="border-b border-line">
              {["macOS asks about", "When", "Why", "If you say no"].map((head) => (
                <th key={head} scope="col" className="px-5 py-4 font-normal md:px-10">
                  {head}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {asks.map(({ name, when, why, without }) => (
              <tr key={name} className="border-line transition-colors not-last:border-b hover:bg-panel">
                <th scope="row" className="px-5 py-7 text-xl font-bold md:px-10 md:text-2xl">
                  {name}
                </th>
                <td className="px-5 py-7 font-mono text-xs text-clay md:px-10">{when}</td>
                <td className="px-5 py-7 md:px-10">{why}</td>
                <td className="px-5 py-7 text-soft md:px-10">{without}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}
