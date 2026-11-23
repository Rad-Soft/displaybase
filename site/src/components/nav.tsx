import { GithubButton } from "./github-button";
import { Logo } from "./logo";

const links = [
  ["#packet", "Protocol"],
  ["#wiring", "Wiring"],
  ["#permissions", "Permissions"],
  ["#needs", "Requirements"],
];

export function Nav() {
  return (
    <header className="sticky top-0 z-20 border-b border-line bg-page">
      <nav className="flex h-16 items-center justify-between gap-6 px-5 md:px-10">
        <a href="#top" aria-label="Displaybase, back to top">
          <Logo className="h-7 w-auto" />
        </a>
        <div className="flex items-center gap-8">
          {links.map(([href, label]) => (
            <a key={href} href={href} className="hidden font-mono text-xs text-soft transition-colors hover:text-ink lg:block">
              {label}
            </a>
          ))}
          <GithubButton small />
        </div>
      </nav>
    </header>
  );
}
