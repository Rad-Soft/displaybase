import { Logo } from "./logo";

export function Footer() {
  return (
    <footer className="border-t border-line px-5 pt-10 pb-8 md:px-10">
      <p className="text-soft">
        Made by{" "}
        <a href="https://radsoftinc.com" className="font-semibold text-ink underline decoration-clay decoration-2 underline-offset-4 hover:text-clay">
          Rad Soft
        </a>
      </p>
      <Logo className="mt-14 h-auto w-full text-line" />
    </footer>
  );
}
