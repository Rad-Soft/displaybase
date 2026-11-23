import Image from "next/image";
import { GithubButton } from "./github-button";
import { Mesh } from "./mesh";
import { Shot } from "./shot";

export function Hero() {
  return (
    <section id="top" className="relative isolate flex min-h-[calc(100dvh-4rem)] flex-col justify-between gap-12 overflow-hidden px-5 pt-10 pb-10 md:px-10 md:pt-14 lg:max-h-[60rem]">
      <Mesh className="absolute inset-0 -z-20 opacity-55" />
      <Image
        src="/photos/monolith.webp"
        alt=""
        fill
        sizes="(min-width: 1440px) 1440px, 100vw"
        loading="eager"
        fetchPriority="high"
        className="-z-10 object-cover object-[78%_50%] mix-blend-lighten max-lg:opacity-45"
      />
      <h1 className="rise text-[clamp(3.6rem,8.2vw,7.4rem)] leading-[0.88] font-bold tracking-[-0.035em]">
        One desk,
        <br />
        two
        <br />
        computers.
      </h1>
      <div className="flex flex-wrap items-end justify-between gap-10">
        <div className="rise max-w-md [animation-delay:120ms]">
          <p className="text-lg leading-relaxed md:text-xl">Press a button and your monitor moves to your PC. Press again and everything goes back.</p>
          <div className="mt-8 flex flex-wrap items-center gap-x-7 gap-y-4">
            <GithubButton />
            <a href="#packet" className="font-semibold underline decoration-clay decoration-2 underline-offset-[6px] hover:text-clay">
              See how it works
            </a>
          </div>
        </div>
        <Shot
          name="menu-pc"
          alt="The Displaybase menu: a map of the desk with the 32-inch screen on the gaming PC, and a button to bring everything back"
          width={660}
          height={882}
          sizes="16rem"
          eager
          className="rise w-56 drop-shadow-2xl [animation-delay:200ms] md:w-60"
        />
      </div>
    </section>
  );
}
