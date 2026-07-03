---
name: create-mcp
description: Full MCP development lifecycle for Codex. Use when Codex needs to create, build, scaffold, audit, improve, package, publish, or make discoverable an MCP server; also for Smithery quality, MCP client compatibility, hosted versus stdio decisions, tool descriptions, tool annotations, prompts, package metadata, and directory submission.
---

# create-mcp for Codex

Use this skill to build or audit MCP servers from inside Codex. Keep the
existing `create-mcp` repo as the source of truth; this file is the Codex
entrypoint and adapter.

## Load The Workflow

Before creating or auditing an MCP, read the canonical workflow:

- Installed Codex skill: `references/create-mcp-workflow.md`
- Source repo checkout: `../../skill.md`

Then read only the references needed for the task:

- TypeScript scaffolding: `references/typescript-boilerplate.md` or `../../references/typescript-boilerplate.md`
- Smithery config and scoring: `references/smithery-config.md` or `../../references/smithery-config.md`
- Stdio versus hosted deployment: `references/deployment-guide.md` or `../../references/deployment-guide.md`

## Codex Adaptation Rules

- Prefer editing the user's current repo, not creating a separate MCP repo, unless the user asks for a standalone package.
- For existing MCPs, audit first: map tools, prompts, resources, package metadata, install docs, config files, caching, and error handling before patching.
- For new MCPs, ask only the missing high-impact questions: data source, public/private data, client target, stdio versus hosted, auth, read/write surface.
- Use the repo's existing language and framework when an MCP already exists. Do not rewrite a Python MCP into TypeScript just because the reference boilerplate is TypeScript.
- For public data, start read-only. For private user data, require authentication and avoid exposing stored secrets, resumes, or personal records until the user explicitly approves that surface.
- Keep tool outputs compact by default. Add full-detail tools separately only when users need them.
- Run the smallest relevant validation: typecheck/build for TypeScript MCPs, import/tool tests for Python MCPs, and config validation for generated Smithery files.

## Tool Naming

Use names that work in the target client. If a client rejects dot notation, use
underscores such as `jobhunter_latest_jobs` and keep hierarchy in titles,
descriptions, README, and Smithery metadata. If the target client and directory
accept dot notation, names like `jobhunter.latest_jobs` are fine.

## Output Standard

End with:

- what files changed
- what validation passed or could not run
- what was intentionally skipped and when to add it
