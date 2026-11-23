import { codeToHtml, createCssVariablesTheme, type ShikiTransformer } from "shiki";

const theme = createCssVariablesTheme({ name: "displaybase", variablePrefix: "--code-", fontStyle: true });

// the bash grammar lumps flags and links in with every other argument
const flagsAndLinks: ShikiTransformer = {
  span(node) {
    const child = node.children[0];
    const text = child?.type === "text" ? child.value.trim() : "";
    if (/^--?[a-z]/i.test(text)) node.properties.style = "color:var(--code-token-constant)";
    if (/^https?:/.test(text)) node.properties.style = "color:var(--code-token-link)";
  },
};

export async function highlight(code: string) {
  "use cache";
  return codeToHtml(code, { lang: "bash", theme, transformers: [flagsAndLinks] });
}
