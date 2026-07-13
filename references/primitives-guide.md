# Primitives Guide

Read this during Phase 2 (Design) of the CREATE PATH to decide which MCP primitive each
planned capability should be, during Phase 3 (Build) for the v1 SDK snippets, and during
the AUDIT PATH resources check.

---

## Which primitive?

| Primitive | Use when | Status |
|---|---|---|
| **Tool** (default) | Any action, side effect, write, or computation. Most capabilities are tools. | see `references/typescript-boilerplate.md` |
| **Resource** | A static, read-only dataset — same content every call, no meaningful parameters. | covered below |
| **Resource template** | A parameterized, hierarchical read — one string arg drives a listing (e.g. `docs://{category}`). | stub — T3 fills |
| **Prompt** | A recurring workflow that chains multiple tools in a known order. | stub — T4 fills |

**Tools-only is a valid, common answer.** Stripe's MCP server exposes only tools ("The
server exposes the following MCP tools") — a transactional API has no static,
URI-addressable data worth modeling as a resource. Don't force resources or prompts onto a
server that doesn't need them.

---

## Static resources

### When the heuristic fires

Fires when a tool's zero-arg or default-branch call would return a static dataset: the
same content on every call, no parameter that changes the result. If you're about to write
a tool like `list_flowers()` that takes no meaningful arguments and just returns a fixed
JSON blob, make it a resource instead.

Validated 3x on japan-seasons: `flowers_spots`, `festivals_list`, and `fruit_farms` were
each originally a zero-arg tool returning static data, and each converted cleanly to a
resource.

Don't apply this to a tool where the no-arg case is one branch among several live,
parameterized branches — only convert the capability if there's no meaningful
parameterization at all.

### TypeScript SDK v1

```typescript
server.registerResource(
  "flowers",
  "seasons://flowers",
  {
    title: "Seasonal Flowers",
    description: "Current blooming flowers across Japan by region.",
    mimeType: "application/json",
  },
  async (uri) => ({
    contents: [
      {
        uri: uri.href,
        mimeType: "application/json",
        text: JSON.stringify(FLOWERS_DATA),
      },
    ],
  })
);
```

Signature: `registerResource(name, uri, {title, description, mimeType}, readCallback)`.
`mimeType` belongs in both the registration metadata and each `contents[]` entry the
callback returns — the SDK does not propagate one from the other. Binary content uses
`blob` (base64) in the content entry instead of `text`.

### Python FastMCP v1

```python
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("your-mcp-name")

@mcp.resource(
    "seasons://flowers",
    name="flowers",
    title="Seasonal Flowers",
    description="Current blooming flowers across Japan by region.",
    mime_type="application/json",  # REQUIRED for JSON/binary — see gotcha below
)
def flowers() -> dict:
    return FLOWERS_DATA
```

**Gotcha, called out loudly: FastMCP silently defaults every resource to `text/plain`.**
`mime_type` is an optional keyword with no inference from the return type: return a `dict`
and the content still gets served as `text/plain` unless `mime_type` is passed explicitly.
Any JSON or binary resource MUST pass `mime_type` (`"application/json"`, `"image/png"`,
etc.). This is a real bug class, not a style nit — it's the exact bug the AUDIT path checks
for, and the one planted in `evals/files/broken-mcp-index.ts` (T2).

### Custom URI scheme

Use a `scheme://noun` pattern specific to the server's domain, not a generic one:

- `seasons://flowers`, `seasons://festivals` (japan-seasons)
- `docs://readme`, `stats://catalog` (generic examples)

Avoid using `resource://` or `data://` as the scheme itself — it tells the client nothing
about what the resource is. Keep the noun consistent with how the client refers to it in
conversation.

### Capability note: subscribe / listChanged

`resources.subscribe` and `resources.listChanged` are independent optional capability
flags. Declaring one does not imply the other, and neither is required for a working
resource.

- Plain list + read (the case covered above) needs **neither** flag.
- `listChanged`: declare only if the server calls `server.sendResourceListChanged()` when
  the resource set actually changes at runtime (rare for static resources).
- `subscribe`: declare only if the server implements `resources/subscribe` and
  `resources/unsubscribe` request handlers and pushes `notifications/resources/updated`.

Declaring a flag without the matching implementation is an AUDIT-path bug: capability
declared but not implemented.
