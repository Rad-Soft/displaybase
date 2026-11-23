import { GithubLogoIcon } from "@phosphor-icons/react/dist/ssr";
import { repo } from "@/lib/links";

export function GithubButton({ small = false }: { small?: boolean }) {
  return (
    <a
      href={repo}
      className={`inline-flex items-center gap-2.5 bg-ink font-semibold whitespace-nowrap text-deep transition-colors duration-200 hover:bg-clay active:scale-[0.98] ${small ? "px-4 py-2 text-sm" : "px-6 py-4"}`}
    >
      <GithubLogoIcon size={small ? 18 : 20} weight="fill" aria-hidden />
      Get it on GitHub
    </a>
  );
}
