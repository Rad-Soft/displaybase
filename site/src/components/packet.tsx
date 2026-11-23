"use client";

import { useState } from "react";
import { hex, inputs, packet } from "@/lib/ddc";

// who each byte belongs to
const tone = ["text-sky", "text-sky", "text-soft", "text-ink", "text-ink", "text-clay", "text-clay", "text-soft"];

export function Packet() {
  const [input, setInput] = useState<(typeof inputs)[number]>(inputs[0]);

  return (
    <section id="packet" className="border-t border-line">
      <div className="grid gap-10 px-5 py-16 md:px-10 md:py-24 lg:grid-cols-[7fr_5fr] lg:items-end">
        <h2 className="text-5xl leading-[0.95] font-bold tracking-[-0.025em] md:text-7xl">Eight bytes move a screen.</h2>
        <p className="max-w-[46ch] text-lg leading-relaxed text-soft">
          Your monitor has been able to do this all along. Displaybase sends it one DDC/CI command, reads the input back, and tries up to four times before it believes the answer.
        </p>
      </div>
      <div role="group" aria-label="Input to switch to" className="flex flex-wrap border-t border-line">
        {inputs.map((item) => (
          <button
            key={item.code}
            type="button"
            aria-pressed={item.code === input.code}
            onClick={() => setInput(item)}
            className={`grow border-line px-5 py-4 text-left font-mono text-xs transition-colors not-last:border-r md:px-10 md:text-sm ${item.code === input.code ? "bg-clay text-deep" : "text-soft hover:bg-panel hover:text-ink"}`}
          >
            {item.name}
          </button>
        ))}
      </div>
      <ol aria-live="polite" className="grid grid-cols-4 border-t border-line lg:grid-cols-8">
        {packet(input.code).map((byte, i) => (
          <li
            key={byte.name}
            className="border-line px-4 py-8 not-nth-[4n]:border-r max-lg:nth-[-n+4]:border-b md:px-6 md:py-12 lg:border-r lg:not-nth-[4n]:border-r lg:last:border-r-0"
          >
            <span key={byte.value} className={`flip block font-mono text-4xl font-medium tracking-tight md:text-6xl ${tone[i]}`}>
              {hex(byte.value)}
            </span>
            <span className="mt-4 block font-mono text-xs text-soft">{byte.name}</span>
          </li>
        ))}
      </ol>
    </section>
  );
}
