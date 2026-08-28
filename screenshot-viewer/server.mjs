import { constants } from "node:fs"
import { open, readdir, realpath, stat } from "node:fs/promises"
import { createServer } from "node:http"
import { timingSafeEqual } from "node:crypto"
import path from "node:path"

const port = Number.parseInt(process.env.PORT || "8080", 10)
const root = await realpath(process.env.SCREENSHOT_ROOT || "/screenshots")
const username = process.env.VIEWER_USERNAME
const password = process.env.VIEWER_PASSWORD
const imageName = /^[A-Za-z0-9][A-Za-z0-9._-]*\.(?:png|jpe?g|webp)$/i

if (!username || !password) throw new Error("VIEWER_USERNAME and VIEWER_PASSWORD are required")

function equal(left, right) {
  const a = Buffer.from(left)
  const b = Buffer.from(right)
  return a.length === b.length && timingSafeEqual(a, b)
}

function authorized(request) {
  const value = request.headers.authorization
  if (!value?.startsWith("Basic ")) return false
  let decoded
  try {
    decoded = Buffer.from(value.slice(6), "base64").toString("utf8")
  } catch {
    return false
  }
  const separator = decoded.indexOf(":")
  if (separator < 0) return false
  return equal(decoded.slice(0, separator), username) && equal(decoded.slice(separator + 1), password)
}

function headers(contentType) {
  return {
    "Cache-Control": "private, no-store",
    "Content-Security-Policy": "default-src 'none'; img-src 'self'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'",
    "Content-Type": contentType,
    "Referrer-Policy": "no-referrer",
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
  }
}

function escapeHtml(value) {
  return value.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;")
}

async function index() {
  const entries = await readdir(root, { withFileTypes: true })
  const files = await Promise.all(
    entries
      .filter((entry) => entry.isFile() && imageName.test(entry.name))
      .map(async (entry) => ({ name: entry.name, modified: (await stat(path.join(root, entry.name))).mtimeMs })),
  )
  files.sort((a, b) => b.modified - a.modified)
  const items = files
    .map(({ name }) => {
      const safe = escapeHtml(name)
      const encoded = encodeURIComponent(name)
      return `<a href="/${encoded}"><img src="/${encoded}" alt="${safe}" loading="lazy"><span>${safe}</span></a>`
    })
    .join("")
  return `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>OpenCode Screenshots</title><style>body{margin:0;background:#111;color:#eee;font:14px system-ui;padding:24px}h1{font-size:20px;margin:0 0 20px}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:18px}a{color:#ddd;text-decoration:none;background:#1d1d1d;border:1px solid #333;border-radius:8px;overflow:hidden}img{display:block;width:100%;height:190px;object-fit:contain;background:#080808}span{display:block;padding:10px;overflow-wrap:anywhere}</style></head><body><h1>OpenCode Screenshots</h1><div class="grid">${items}</div></body></html>`
}

const server = createServer(async (request, response) => {
  let fileHandle
  try {
    const url = new URL(request.url || "/", "http://localhost")
    if (url.pathname === "/healthz") {
      response.writeHead(200, headers("text/plain; charset=utf-8"))
      response.end("ok\n")
      return
    }
    if (!authorized(request)) {
      response.writeHead(401, { ...headers("text/plain; charset=utf-8"), "WWW-Authenticate": 'Basic realm="OpenCode Screenshots", charset="UTF-8"' })
      response.end("Authentication required.\n")
      return
    }
    if (request.method !== "GET" && request.method !== "HEAD") {
      response.writeHead(405, { ...headers("text/plain; charset=utf-8"), Allow: "GET, HEAD" })
      response.end("Method not allowed.\n")
      return
    }
    if (url.pathname === "/") {
      const body = await index()
      response.writeHead(200, headers("text/html; charset=utf-8"))
      response.end(request.method === "HEAD" ? undefined : body)
      return
    }

    const name = decodeURIComponent(url.pathname.slice(1))
    if (!imageName.test(name) || path.basename(name) !== name) {
      response.writeHead(404, headers("text/plain; charset=utf-8"))
      response.end("Not found.\n")
      return
    }
    const file = path.join(root, name)
    fileHandle = await open(file, constants.O_RDONLY | constants.O_NOFOLLOW)
    const info = await fileHandle.stat()
    if (!info.isFile()) throw new Error("Not a regular file")
    const extension = path.extname(name).toLowerCase()
    const contentType = extension === ".png" ? "image/png" : extension === ".webp" ? "image/webp" : "image/jpeg"
    response.writeHead(200, { ...headers(contentType), "Content-Length": info.size })
    if (request.method === "HEAD") {
      await fileHandle.close()
      fileHandle = undefined
      response.end()
    } else {
      const stream = fileHandle.createReadStream()
      fileHandle = undefined
      stream.pipe(response)
    }
  } catch {
    await fileHandle?.close().catch(() => {})
    if (!response.headersSent) response.writeHead(404, headers("text/plain; charset=utf-8"))
    response.end("Not found.\n")
  }
})

server.listen(port, "0.0.0.0")
