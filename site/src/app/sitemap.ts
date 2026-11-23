import type { MetadataRoute } from "next";
import { site } from "@/lib/links";

export default function sitemap(): MetadataRoute.Sitemap {
  return [{ url: site }];
}
