import Image from "next/image";

type ShotProps = { name: string; alt: string; width: number; height: number; sizes: string; className?: string; eager?: boolean };

export function Shot({ name, eager = false, ...image }: ShotProps) {
  return <Image {...image} src={`/shots/${name}-dark.webp`} loading={eager ? "eager" : "lazy"} />;
}
