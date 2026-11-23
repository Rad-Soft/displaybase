import Image from "next/image";

const steps = [
  { call: "AXUIElement", title: "Remembers every window", text: "Position, size and which screen it was on." },
  { call: "VCP 0x60", title: "Switches the input", text: "Then reads it back, so a monitor that ignored the command doesn't take your screen away." },
  { call: "CGSConfigureDisplayEnabled", title: "Turns the screen off in macOS", text: "Windows and the pointer can't wander onto it. It lasts for the session, so logging out always brings it back." },
  { call: "MPDisplay", title: "Holds the rotation", text: "macOS brings a new set of screens up unrotated. A portrait screen stays portrait." },
  { call: "CGConfigureDisplayOrigin", title: "Moves the menu bar", text: "To the screen the Mac keeps." },
  { call: "IOUSBHostDevice", title: "Watches the keyboard", text: "When it moves back, you can have everything return, or only borrow the keyboard." },
];

export function Sequence() {
  return (
    <section className="border-t border-line">
      <div className="grid lg:grid-cols-[5fr_7fr]">
        <div className="relative min-h-[26rem] border-line max-lg:border-b lg:border-r">
          <div className="lg:sticky lg:top-16 lg:h-[calc(100dvh-4rem)] lg:max-h-[56rem]">
            <Image src="/photos/board.webp" alt="A monitor's circuit board with one blue and one orange trace lit" fill sizes="(min-width: 1024px) 42vw, 100vw" className="object-cover" />
            <div className="absolute inset-0 bg-linear-to-t from-page via-page/20 to-transparent" />
            <h2 className="absolute inset-x-5 bottom-8 text-5xl leading-[0.95] font-bold tracking-[-0.025em] md:inset-x-10 md:bottom-12 md:text-6xl">One press, six system calls.</h2>
          </div>
        </div>
        <ol>
          {steps.map(({ call, title, text }) => (
            <li key={call} className="grid gap-x-10 gap-y-3 border-line px-5 py-10 not-last:border-b md:px-10 md:py-14 xl:grid-cols-[16rem_1fr]">
              <code className="font-mono text-xs break-all text-clay md:text-sm">{call}</code>
              <div>
                <h3 className="text-2xl font-bold md:text-3xl">{title}</h3>
                <p className="mt-2 max-w-[48ch] text-lg leading-relaxed text-soft">{text}</p>
              </div>
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}
