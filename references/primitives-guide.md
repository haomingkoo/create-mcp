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
| **Resource template** | A parameterized, hierarchical read — one string arg drives a listing (e.g. `docs://{category}`). | covered below |
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
each a dataset first exposed through tools, and each promoted cleanly to a resource
(the tools remain for parameterized access; the resources serve the full datasets).

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

---

## Resource templates

### When the heuristic fires

Fires when a capability is a **read-only tool with exactly one or a few string
parameters that select from a finite, hierarchical space**, where the parameter narrows a
listing rather than triggering a side effect. `seasons://spots/{prefecture}` (viewing
spots in one prefecture) and `docs://{category}` (documents in one category) are template
shapes. If the capability would otherwise be `list_x(category: string)` with no other
live branches, it's a template, not a tool.

The canonical real-world case is GitHub's official MCP server: its repository-files-at-refs
resources are addressed as templates keyed by owner/repo/ref/path, so the URI itself is
the read, not a tool call with the same arguments.

Don't apply this to a capability that also writes, ranks/scores results, or takes
non-hierarchical filter combinations; those stay tools.

### RFC 6570 URI template syntax

Resource template URIs follow [RFC 6570](https://www.rfc-editor.org/rfc/rfc6570). The
forms both v1 SDKs document and handle reliably:

| Form | Meaning | Example |
|---|---|---|
| `{var}` | Simple string expansion, stops at `/` | `seasons://spots/{prefecture}` |
| `{+var}` | Reserved expansion, allows `/` inside the value | `docs://{+path}` |
| `{/var}` | Path-segment expansion | `docs{/category}` |
| `{?var}` | Query-parameter expansion | `search://items{?query}` |

Stick to plain `{var}` unless you've confirmed the SDK version and target client both
handle the extended operators. It's the form used in every template example in both
SDKs' own docs, and the one guaranteed to round-trip.

### TypeScript SDK v1

```typescript
import { ResourceTemplate } from "@modelcontextprotocol/sdk/server/mcp.js";

server.registerResource(
  "spots-by-prefecture",
  new ResourceTemplate("seasons://spots/{prefecture}", {
    list: undefined, // REQUIRED key, see gotcha below
  }),
  {
    title: "Viewing Spots by Prefecture",
    description: "Cherry blossom viewing spots in one prefecture.",
    mimeType: "application/json",
  },
  async (uri, { prefecture }) => ({
    contents: [
      {
        uri: uri.href,
        mimeType: "application/json",
        text: JSON.stringify(getSpots(prefecture)),
      },
    ],
  })
);
```

**Gotcha, called out loudly: `list` is a REQUIRED key on the `ResourceTemplate` options
object, there is no default.** If the instance space is enumerable, pass a `list`
callback that returns `{ resources: [...] }` so clients can discover instances via
`resources/list`. If it isn't enumerable (an unbounded free-text space, e.g. arbitrary
repo paths), pass `list: undefined` explicitly. Omitting the key entirely is a
TypeScript compile error, not a silent default.

The read callback's second argument is an object keyed by the URI template's variable
names. **The destructured parameter names must match the `{variable}` names in the URI
template exactly**: `{prefecture}` in the URI means the callback destructures
`{ prefecture }`, not `{ prefectureName }` or any other name. A mismatch doesn't throw:
the destructured value is silently `undefined` and the handler runs with a missing
argument. This is the exact bug planted as T3a in `evals/files/broken-mcp-index.ts`.

### Python FastMCP v1

```python
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("your-mcp-name")

@mcp.resource(
    "seasons://spots/{prefecture}",
    name="spots-by-prefecture",
    title="Viewing Spots by Prefecture",
    description="Cherry blossom viewing spots in one prefecture.",
    mime_type="application/json",
)
def spots_by_prefecture(prefecture: str) -> dict:
    return get_spots(prefecture)
```

**Function parameter names must match the URI template variables exactly.** Unlike the
TypeScript SDK's silent-`undefined` failure mode, FastMCP enforces this at decoration
time: a placeholder like `{prefecture}` paired with a function parameter named `district`
raises `ValueError` when the module loads, before the server ever starts. Stricter than
TypeScript here, but still worth an explicit AUDIT check; don't rely on import-time
errors alone if the audit is reading source without executing it.

---

## Completions

Completions are a **companion to resource templates and prompts, never a standalone
primitive.** GitHub's official MCP server is the canonical case: it implements
`completion/complete` only for the path-segment arguments of its resource templates
(owner, repo, branch, sha, tag, path, PR number), nothing else in the server uses
completions. If a server has no template with a free-text parameter and no prompt with an
open-ended argument, it has nothing to complete.

### Two distinct mechanisms, don't conflate them

| Mechanism | Wraps | Declared inside |
|---|---|---|
| `completable(schema, cb)` | A **prompt argument's** zod schema | `argsSchema` passed to `registerPrompt` |
| `complete: { param: cb }` | A **resource template's** URI variables | The second argument of the `ResourceTemplate` constructor |

```typescript
import { completable } from "@modelcontextprotocol/sdk/server/completable.js";
import { ResourceTemplate } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";

// Mechanism 1: completable() wraps a PROMPT argument
server.registerPrompt(
  "plan_koyo_trip",
  {
    description: "Plan an autumn-leaves viewing trip.",
    argsSchema: {
      prefecture: completable(z.string(), (value) =>
        PREFECTURES.filter((p) => p.startsWith(value))
      ),
    },
  },
  ({ prefecture }) => ({ /* ... */ })
);

// Mechanism 2: the `complete` map on a ResourceTemplate's constructor options
new ResourceTemplate("seasons://spots/{prefecture}", {
  list: undefined,
  complete: {
    prefecture: async (value) =>
      PREFECTURES.filter((p) => p.startsWith(value)),
  },
});
```

Both callbacks share the same `(value, context?)` signature, but they're wired into
different constructors and cover different primitives: fixing a prompt argument's
completion doesn't touch a template's, and vice versa.

### Capability declaration

`McpServer`'s high-level API additively merges `completions: {}` into the advertised
capabilities the first time it detects a real `completable()` field or a template
`complete` callback, so you don't have to declare it by hand in the common case. But the
template-side detection keys off an **exact match** between the `complete` map's keys and
the URI template's real variable names, the same name-matching contract as the read
callback, above. A typo'd key means the callback is present in source but never wired up:
the SDK never finds a matching variable, never enables the completion handler, and the
server never advertises `completions` even though the code looks complete. That is the
T3b bug planted in the fixture: implemented, but the capability a client needs in order
to discover it is never declared.

The **low-level `Server` class has no such auto-detection at all.** Capabilities there
are never inferred from registered handlers; every capability, `completions` included,
must be passed to the constructor explicitly:

```typescript
new Server({ name: "s", version: "0" }, { capabilities: { completions: {} } });
```

Using a low-level completion handler without declaring the capability fails at request
time, not at startup, another reason to check the declared capabilities directly during
an audit rather than assuming a handler's presence is enough.

### Results cap at 100

A completion response's `values` array is capped at 100 items regardless of how many
matches exist; `total` and `hasMore` describe the full match count so clients know there
is more even though only the first 100 come back. Sort or rank before truncating; don't
return an arbitrary 100.
