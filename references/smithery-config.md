# Smithery Config & Scoring Reference

Read this during Phase 3 (Build), the AUDIT PATH, and the PUBLISH PATH.

---

## smithery.yaml — stdio servers (installed via npx)

**With auth (API key):**
```yaml
startCommand:
  type: stdio
  configSchema:
    type: object
    properties:
      apiKey:
        type: string
        title: "API Key"
        description: "Your API key from example.com/settings"
    required: []
  commandFunction: |-
    (config) => ({
      command: "npx",
      args: ["your-mcp-name"],
      env: config.apiKey ? { API_KEY: config.apiKey } : {}
    })
```

**No auth:**
```yaml
startCommand:
  type: stdio
  configSchema:
    type: object
    properties: {}
    required: []
  commandFunction: |-
    (config) => ({ command: "npx", args: ["your-mcp-name"] })
```

The `required: []` matters — Smithery awards 15pt for optional config (vs. 10pt if you mark fields as required).

---

## smithery.remote-config.json — hosted HTTP servers

**With optional auth:**
```json
{
  "type": "object",
  "properties": {
    "apiKey": {
      "type": "string",
      "title": "API Key",
      "description": "Optional API key for authenticated endpoints"
    }
  },
  "required": []
}
```

**No config needed:**
```json
{ "type": "object", "properties": {}, "required": [] }
```

---

## Smithery scoring reference

| Category | Points | How to earn it |
|---|---|---|
| Tool descriptions | 12pt | Verb-first, ≤2 sentences, states next tool |
| Parameter descriptions | 11pt | `.describe()` + `.meta({ title })` on every param |
| Annotations | 7pt | `readOnlyHint` minimum; `openWorldHint` for external APIs |
| **Tool names** | **5pt** | **Dot notation `domain.action` — NOT `get_*` snake_case** |
| Prompts | 5pt | Register ≥1 prompt for a real workflow |
| Resources | 5pt | Awarded automatically — no action needed |
| Server description | 10pt | Set in Smithery UI settings (not package.json) |
| Homepage | 10pt | `homepage` field in package.json |
| Icon | 7pt | Upload in Smithery UI settings |
| Display name | 3pt | Set in Smithery UI settings |
| Config schema | 10pt | `smithery.yaml` or `smithery.remote-config.json` present |
| Optional config | 15pt | All config fields in `required: []` (not required) |

**Total: 100pt**

---

## Score ladder

| Score | What's typically missing |
|---|---|
| ~60 | Noun-first descriptions, no annotations, incomplete package.json |
| ~75 | Descriptions fixed, annotations added, package.json complete |
| ~85 | Server instructions added, parameter descriptions complete |
| ~90 | Prompts registered, caching and error handling clean |
| ~95 | smithery.yaml with configSchema, README polished |
| ~98 | All code dimensions maxed, Smithery UI metadata not set |
| **100** | **Dot notation tool names + Smithery UI icon/display name/description** |

---

## The dot notation rule

Smithery's exact tooltip text: *"Measures how well tool names form a navigable tree using dot-notation (e.g., admin.tools.list). Scores higher when hierarchy depth matches the ideal for the number of tools — flat lists of many tools and unnecessarily deep nesting both reduce the score."*

Rules:
- Use `domain.action` format: `sakura.forecast`, `user.search`, `order.create`
- 2–6 tools per domain prefix
- Max 2 levels deep
- Uniform `get_*` caps at 3/5 regardless of how descriptive the names are

Example structure (12 tools, 6 domains):
```
sakura.forecast    koyo.forecast    weather.forecast
sakura.spots       koyo.spots       flowers.spots
sakura.best_dates  koyo.best_dates  fruit.seasons
                   kawazu.forecast  fruit.farms
                                    festivals.list
```

---

## Smithery UI metadata (20pt — code alone can't earn these)

After the server is indexed on Smithery, complete these in the UI:

1. smithery.ai → your server → Settings
2. **Upload icon** (PNG, 256×256 recommended) → **+7pt**
3. **Set display name** (human-readable, not the npm slug) → **+3pt**
4. **Set server description** (1–2 sentences, separate from package.json) → **+10pt**

These 20 points require manual action. Remind the user after pushing code.

---

## Smithery publish commands

**Hosted HTTP servers:**
```bash
npx @smithery/cli mcp publish \
  "https://YOUR_DOMAIN/mcp" \
  -n YOUR_GITHUB_USERNAME/YOUR_REPO_NAME \
  --config-schema "$(cat smithery.remote-config.json)"
```

**stdio servers:** smithery.ai → Add Server → paste GitHub URL → trigger scan.
