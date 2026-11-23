import { existsSync } from "node:fs";
import { mkdir } from "node:fs/promises";

// served from here so it loads for everyone, but kept out of the repo
const file = "public/fonts/kerf-variable.woff2";

if (!existsSync(file)) {
  const response = await fetch("https://radsoftinc.com/fonts/kerf-variable.woff2").catch(() => null);
  const bytes = response?.ok ? new Uint8Array(await response.arrayBuffer()) : null;
  if (bytes && new TextDecoder().decode(bytes.slice(0, 4)) === "wOF2") {
    await mkdir("public/fonts", { recursive: true });
    await Bun.write(file, bytes);
  } else {
    console.warn("couldn't fetch Kerf, the page will ask radsoftinc.com for it");
  }
}
