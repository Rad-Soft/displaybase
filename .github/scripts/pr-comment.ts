type Comment = { id: number; body: string }

async function api(
  method: string,
  url: string,
  token: string,
  body?: unknown
): Promise<Response> {
  const res = await fetch(url, {
    method,
    headers: {
      authorization: `Bearer ${token}`,
      accept: "application/vnd.github+json",
      "content-type": "application/json",
      "user-agent": "displaybase-ci",
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  })
  if (!res.ok) throw new Error(`${method} ${url}: ${res.status}`)
  return res
}

// one comment per marker: update it if it exists, otherwise create it
export async function upsertPrComment(
  marker: string,
  body: string,
  env: Record<string, string | undefined> = process.env
): Promise<void> {
  const repo = env.REPO ?? ""
  const pr = env.PR_NUMBER ?? ""
  const token = env.GH_TOKEN ?? ""
  const base = env.GITHUB_API_URL ?? "https://api.github.com"
  if (!/^[\w.-]+\/[\w.-]+$/.test(repo)) throw new Error("REPO is not owner/name")
  if (!/^\d+$/.test(pr)) throw new Error("PR_NUMBER is not a number")
  if (!token) throw new Error("GH_TOKEN is empty")

  const url = `${base}/repos/${repo}/issues/${pr}/comments`
  let existing: Comment | undefined
  for (let page = 1; !existing; page++) {
    const res = await api("GET", `${url}?per_page=100&page=${page}`, token)
    const list = (await res.json()) as Comment[]
    if (!Array.isArray(list)) throw new Error("unexpected comments response")
    existing = list.find((c) => c.body.startsWith(marker))
    if (list.length < 100) break
  }
  if (existing) {
    await api(
      "PATCH",
      `${base}/repos/${repo}/issues/comments/${existing.id}`,
      token,
      { body }
    )
    console.log(`updated comment ${existing.id}`)
  } else {
    await api("POST", url, token, { body })
    console.log("created comment")
  }
}
