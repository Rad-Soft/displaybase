"use client";

import { CheckIcon, CopyIcon } from "@phosphor-icons/react";
import { useEffect, useState } from "react";

export function CopyButton({ text, label }: { text: string; label: string }) {
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    if (!copied) return;
    const timer = setTimeout(() => setCopied(false), 1800);
    return () => clearTimeout(timer);
  }, [copied]);

  function copy() {
    navigator.clipboard.writeText(text).then(
      () => setCopied(true),
      () => setCopied(false),
    );
  }

  const Icon = copied ? CheckIcon : CopyIcon;
  return (
    <button
      type="button"
      onClick={copy}
      aria-label={copied ? "Copied" : `Copy: ${label}`}
      className="inline-flex items-center gap-2 border border-line bg-page px-4 py-2.5 font-mono text-xs text-ink transition-colors hover:border-clay hover:text-clay active:scale-[0.98]"
    >
      <Icon size={16} weight="bold" aria-hidden />
      {copied ? "Copied" : "Copy"}
    </button>
  );
}
