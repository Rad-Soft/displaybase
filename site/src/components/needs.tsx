import Image from "next/image";

const yes = ["A Mac with Apple silicon, on macOS 15 or later", "Monitors with DDC/CI turned on, plugged into both computers", "Any second computer: Windows, Linux or another Mac", "A USB switch and SSH, if you have them"];
const no = ["Intel Macs", "DisplayLink docks and adapters", "Some LG monitors, which ignore the standard input command", "Two matching monitors that report the same serial number"];

export function Needs() {
  return (
    <section id="needs" className="border-t border-line">
      <div className="grid lg:grid-cols-[7fr_5fr]">
        <div className="px-5 py-16 md:px-10 md:py-24">
          <h2 className="text-5xl leading-[0.95] font-bold tracking-[-0.025em] md:text-7xl">What you need</h2>
          <ul className="mt-12 grid gap-6 text-xl leading-snug md:text-2xl">
            {yes.map((item) => (
              <li key={item} className="max-w-[32ch] border-l-2 border-sky pl-6">
                {item}
              </li>
            ))}
          </ul>
          <h3 className="mt-16 text-xl font-bold">It won&apos;t work with</h3>
          <ul className="mt-6 grid gap-4 text-soft">
            {no.map((item) => (
              <li key={item} className="max-w-[44ch] border-l-2 border-line pl-6">
                {item}
              </li>
            ))}
          </ul>
          <p className="mt-14 max-w-[52ch] leading-relaxed text-soft">It&apos;s early, and so far it has been used on one desk. If your monitor works, or doesn&apos;t, please say so on GitHub.</p>
        </div>
        <div className="relative min-h-[24rem] border-line max-lg:border-t lg:border-l">
          <Image src="/photos/switch.webp" alt="A USB switch with a ring of light, half blue and half orange" fill sizes="(min-width: 1024px) 42vw, 100vw" className="object-cover object-[58%_50%]" />
        </div>
      </div>
    </section>
  );
}
