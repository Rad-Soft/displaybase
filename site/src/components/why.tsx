import Image from "next/image";

export function Why() {
  return (
    <section className="relative isolate overflow-hidden border-t border-line">
      <Image src="/photos/edge.webp" alt="" fill sizes="100vw" className="-z-20 object-cover" />
      <div className="absolute inset-0 -z-10 bg-page/80" />
      <div className="px-5 py-24 md:px-10 md:py-40">
        <h2 className="text-[clamp(3rem,9vw,8.5rem)] leading-[0.9] font-bold tracking-[-0.035em]">
          Nothing moved
          <br />
          the screens.
        </h2>
        <div className="mt-12 grid max-w-5xl gap-x-14 gap-y-7 text-lg leading-relaxed md:mt-20 md:grid-cols-2">
          <p>I work on a MacBook and play on a gaming PC. They share two monitors, and a USB switch moves my keyboard between them. The screens stayed put.</p>
          <p>When a monitor did switch, macOS didn&apos;t know it was gone. Windows stayed on a screen I couldn&apos;t see, the layout reshuffled, and my portrait monitor came up sideways.</p>
          <p>And if I needed the Mac for a second, I didn&apos;t want that to end my game.</p>
          <p>So I wanted one press: the PC on the main screen, the Mac tucked onto the side one, and everything back where it was afterwards. That&apos;s why I built Displaybase.</p>
        </div>
        <p className="mt-10 font-mono text-sm">Geeth, Rad Soft</p>
      </div>
    </section>
  );
}
