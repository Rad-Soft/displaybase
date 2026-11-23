import { Footer } from "@/components/footer";
import { Hero } from "@/components/hero";
import { Install } from "@/components/install";
import { Nav } from "@/components/nav";
import { Needs } from "@/components/needs";
import { Packet } from "@/components/packet";
import { Permissions } from "@/components/permissions";
import { Sequence } from "@/components/sequence";
import { Setup } from "@/components/setup";
import { Why } from "@/components/why";
import { Wiring } from "@/components/wiring";

export default function Home() {
  return (
    <div className="mx-auto max-w-[1440px] border-line xl:border-x">
      <Nav />
      <main>
        <Hero />
        <Packet />
        <Wiring />
        <Why />
        <Sequence />
        <Setup />
        <Permissions />
        <Needs />
        <Install />
      </main>
      <Footer />
    </div>
  );
}
