import { CodeBlock } from "./code-block";
import { GithubButton } from "./github-button";
import { Mesh } from "./mesh";

const install = `brew install --cask rad-soft/tap/displaybase`;

const source = `git clone https://github.com/Rad-Soft/displaybase
cd displaybase
brew install xcodegen
make install`;

export function Install() {
  return (
    <section className="relative isolate overflow-hidden border-t border-line px-5 py-20 md:px-10 md:py-32">
      <Mesh className="absolute inset-0 -z-10" seed={9} />
      <h2 className="text-[clamp(3rem,9vw,8.5rem)] leading-[0.9] font-bold tracking-[-0.035em]">
        Free and
        <br />
        open source.
      </h2>
      <p className="mt-8 max-w-[44ch] text-lg leading-relaxed md:text-xl">Install it with Homebrew and it keeps itself up to date. Or read every line and build it yourself. MIT licensed.</p>
      <div className="mt-10">
        <GithubButton />
      </div>
      <div className="mt-16 grid gap-8 lg:grid-cols-2">
        <div className="bg-page/90 p-6 md:p-8">
          <CodeBlock title="Install with Homebrew" code={install} />
        </div>
        <div className="bg-page/90 p-6 md:p-8">
          <CodeBlock title="Build it yourself" code={source} />
        </div>
      </div>
    </section>
  );
}
