import { highlight } from "@/lib/highlight";
import { CopyButton } from "./copy-button";

export async function CodeBlock({ title, code }: { title: string; code: string }) {
  const html = await highlight(code);
  return (
    <div className="min-w-0">
      <div className="mb-4 flex items-center justify-between gap-4">
        <h3 className="text-xl font-bold">{title}</h3>
        <CopyButton text={code} label={title} />
      </div>
      <div className="code" dangerouslySetInnerHTML={{ __html: html }} />
    </div>
  );
}
