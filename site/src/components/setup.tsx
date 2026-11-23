import { Mesh } from "./mesh";
import { Shot } from "./shot";

const more = [
  { name: "setup-keyboard", alt: "The setup window asking about a shared keyboard", title: "Press your switch's button", text: "It watches what leaves and finds your keyboard by itself. No switch? Skip it." },
  { name: "setup-permissions", alt: "The setup window listing optional permissions", title: "Allow what you want", text: "Every permission is optional, and says what it's for before you click." },
];

export function Setup() {
  return (
    <section className="border-t border-line">
      <div className="relative isolate overflow-hidden px-5 pt-16 md:px-10 md:pt-24">
        <Mesh className="absolute inset-0 -z-10" seed={4} />
        <h2 className="max-w-[15ch] text-5xl leading-[0.95] font-bold tracking-[-0.025em] md:text-7xl">Setup shows you what each choice does.</h2>
        <p className="mt-6 max-w-[46ch] text-lg leading-relaxed">Pick what each screen does and watch the desk change beside it. You can try an input for five seconds before you keep it.</p>
        <Shot
          name="setup-screens"
          alt="The setup window, asking which screens move, next to a live map of the desk"
          width={1600}
          height={1040}
          sizes="(min-width: 1280px) 68rem, 100vw"
          className="mx-auto mt-14 -mb-1 w-full max-w-[68rem] drop-shadow-2xl"
        />
      </div>
      <div className="grid border-t border-line md:grid-cols-2">
        {more.map(({ name, alt, title, text }) => (
          <div key={name} className="border-line p-5 not-last:border-b md:p-10 md:not-last:border-r md:not-last:border-b-0">
            <Shot name={name} alt={alt} width={1600} height={1040} sizes="(min-width: 768px) 42rem, 100vw" className="w-full" />
            <h3 className="mt-8 text-2xl font-bold">{title}</h3>
            <p className="mt-2 max-w-[44ch] text-lg leading-relaxed text-soft">{text}</p>
          </div>
        ))}
      </div>
    </section>
  );
}
