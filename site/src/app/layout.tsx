import type { Metadata, Viewport } from "next";
import { Martian_Mono } from "next/font/google";
import { site } from "@/lib/links";
import "./globals.css";

const martian = Martian_Mono({ variable: "--font-martian", subsets: ["latin"] });

const description =
  "A free, open source Mac app for a desk with two computers. Press a button and your monitor moves to your PC. Press again and everything goes back.";

export const metadata: Metadata = {
  metadataBase: new URL(site),
  title: "Displaybase. One desk, two computers.",
  description,
  alternates: { canonical: "/" },
  openGraph: { title: "Displaybase", description, url: site, siteName: "Displaybase", type: "website" },
  twitter: { card: "summary_large_image", title: "Displaybase", description },
};

export const viewport: Viewport = { themeColor: "#02090e" };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${martian.variable} antialiased`}>
      <head>
        <link rel="preload" as="font" type="font/woff2" href="/fonts/kerf-variable.woff2" crossOrigin="anonymous" />
      </head>
      <body className="font-sans">{children}</body>
    </html>
  );
}
