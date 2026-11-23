"use client";

import Image from "next/image";
import { useState } from "react";
import { Shot } from "./shot";
import { WiringDiagram } from "./wiring-diagram";

const states = [
  { key: "mac", label: "Working", title: "The Mac has every screen", text: "Your windows are where you left them, and the PC is out of the way.", alt: "Both monitors show blue, for the Mac" },
  { key: "pc", label: "Gaming", title: "The PC takes the main screen", text: "The Mac moves its menu bar and windows to the screen it keeps, so chat and music stay in view.", alt: "The tall monitor shows blue for the Mac and the wide one shows orange for the PC" },
  { key: "both", label: "Gaming on both", title: "The PC takes them all", text: "With the laptop open, the Mac carries on there. Switch your keyboard back and one screen comes with it.", alt: "Both monitors show orange, for the PC" },
] as const;

export type Desk = (typeof states)[number]["key"];

export function Wiring() {
  const [active, setActive] = useState(1);
  const state = states[active];

  return (
    <section id="wiring" className="border-t border-line">
      <div className="px-5 py-16 md:px-10 md:py-24">
        <h2 className="max-w-[14ch] text-5xl leading-[0.95] font-bold tracking-[-0.025em] md:text-7xl">Same cables, different owner.</h2>
      </div>
      <div role="group" aria-label="Choose what you're doing" className="flex flex-wrap border-t border-line">
        {states.map((item, i) => (
          <button
            key={item.key}
            type="button"
            aria-pressed={i === active}
            onClick={() => setActive(i)}
            className={`grow border-line px-5 py-4 text-left font-mono text-xs transition-colors not-last:border-r md:px-10 md:text-sm ${i === active ? "bg-clay text-deep" : "text-soft hover:bg-panel hover:text-ink"}`}
          >
            {item.label}
          </button>
        ))}
      </div>
      <div className="overflow-x-auto border-t border-line bg-panel">
        <WiringDiagram desk={state.key} />
      </div>
      <div className="grid border-t border-line lg:grid-cols-[2fr_1fr]">
        <div className="relative aspect-[3/2] lg:aspect-auto lg:min-h-[34rem]">
          {states.map((item, i) => (
            <Image
              key={item.key}
              src={`/photos/desk-${item.key}.webp`}
              alt={i === active ? item.alt : ""}
              fill
              sizes="(min-width: 1024px) 66vw, 100vw"
              className={`object-cover transition-opacity duration-500 ease-out-soft motion-reduce:transition-none ${i === active ? "opacity-100" : "opacity-0"}`}
            />
          ))}
        </div>
        <div className="flex flex-col justify-between gap-10 border-line p-5 max-lg:border-t md:p-10 lg:border-l">
          <div className="relative aspect-[660/882] w-full max-w-[19rem]">
            {states.map((item, i) => (
              <div
                key={item.key}
                aria-hidden={i !== active}
                className={`absolute inset-0 transition-opacity duration-500 ease-out-soft motion-reduce:transition-none ${i === active ? "opacity-100" : "opacity-0"}`}
              >
                <Shot name={`menu-${item.key}`} alt={`The Displaybase menu while ${item.label.toLowerCase()}`} width={660} height={882} sizes="19rem" className="w-full" />
              </div>
            ))}
          </div>
          <div aria-live="polite" className="min-h-32">
            <h3 className="text-2xl font-bold">{state.title}</h3>
            <p className="mt-2 max-w-[40ch] leading-relaxed text-soft">{state.text}</p>
          </div>
        </div>
      </div>
    </section>
  );
}
