# Claude Code Setup for SAP CAP Projects

A developer tooling layer for SAP CAP projects that makes Claude Code context-aware — with auto-detecting setup, skill templates, automatic hooks, and multi-language i18n support out of the box.

---

## What's Inside

```
.claude/
├── setup.js                  → One-time setup script (auto-detects project)
├── settings.json             → Hooks: file guard + CDS syntax check + CSV/i18n sync
├── i18n-config.json          → Supported languages list
├── templates/
│   ├── CLAUDE.md.tpl         → Project context template
│   └── skills/
│       ├── cds-entity.tpl    → Add entity skill
│       ├── cds-service.tpl   → Add service skill
│       ├── cds-auth.tpl      → Add auth skill
│       ├── cds-event.tpl     → Async events skill
│       ├── cds-remote.tpl    → External service skill
│       ├── fiori-page.tpl    → Fiori route/page skill
│       └── wdi5-test.tpl     → E2E test skill
└── memory/
    └── project_context.md    → Persistent project memory for Claude
```

---

## Quick Start

### 1. Install dependencies

```bash
npm install
```

### 2. Run setup

```bash
npm run setup:claude
```

The setup script **auto-detects** everything from your existing files:

| Source | Detected values |
|--------|----------------|
| `package.json` | Project name, description, app directory |
| `db/schema.cds` | CDS namespace, entity list |
| `srv/*.cds` | Service name, URL path, file name |

The only question it asks is which languages to support:

```
Supported languages (comma-separated, e.g: en,de,tr) [en]:
```

### 3. Open Claude Code

```bash
claude
```

### 4. How to use `.claude`

This repository is a Claude Code helper layer for SAP CAP projects, not a full CAP application. Use `.claude` to generate context-aware documentation, skill templates, and hooks for your CAP project.

- `.claude/setup.js` auto-detects your project and writes `CLAUDE.md`, skill `SKILL.md` files, and language config.
- `.claude/settings.json` defines Claude Code hooks for file protection, CDS syntax checking, and schema/i18n sync.
- `.claude/i18n-config.json` stores the supported languages for your app.
- `.claude/templates/skills/` contains skill templates for CAP tasks like entities, services, auth, events, remote services, Fiori pages, and wdi5 tests.
- `.claude/memory/` holds persistent project context for Claude.

To apply `.claude` in a new CAP project, copy the `.claude/` folder into the project root, run `npm install`, then `npm run setup:claude`.

Claude now knows your project's full context — namespace, entities, service paths, app structure — without you having to explain it every time.

---

## Skills

Skills are prompt templates that guide Claude through common CAP development tasks. Trigger them by describing what you want in natural language.

### `cds-entity` — Add a new entity

**Trigger phrases:** "add entity", "new table", "add to data model"

**What it does:** Creates everything needed for a new entity in one go:

```
db/schema.cds              ← Field definitions (appended, no new file)
srv/<service>.cds          ← Service projection
app/labels.cds             ← @title annotations
app/*/webapp/i18n/*.properties  ← i18n key=value pairs for all languages
app/<app>/fiori-service.cds    ← ListReport + ObjectPage + draft
db/data/<namespace>-Entity.csv ← Seed data
```

**Example prompt:**
```
Add a Supplier entity with name, email, country fields. Link it to Product.
```

Use `${APP_DIR}` in the prompt examples when referring to the Fiori app path, for example `app/<app_dir>/webapp/test/wdi5/`.

---

### `cds-service` — Add a new OData service

**Trigger phrases:** "add service", "new API", "create service"

**What it does:** Generates the full service stack:

- `.cds` service definition with `@(requires:)` auth
- `.js` handler with `before` / `on` / `after` hooks skeleton
- `xs-security.json` role definitions (production)
- `package.json` mock users (development)

**Example prompt:**
```
Add a SupplierService with admin role. Expose the Supplier entity.
```

---

### `cds-auth` — Add role-based authorization

**Trigger phrases:** "add auth", "define roles", "who can access"

**What it does:** Sets up all three authorization layers together:

```
CDS @restrict annotations  →  who can do what
xs-security.json           →  CF role definitions
package.json mocked users  →  alice (admin), bob (viewer) for dev
```

**Example prompt:**
```
Add viewer and admin roles to SupplierService. Viewers can only read.
```

---

### `cds-event` — Async events between services

**Trigger phrases:** "add event", "async notification", "inter-service"

**What it does:** Implements the CAP emit/on pattern:

```
Service A  →  this.emit('EntitySubmitted', data)
Service B  →  svcA.on('EntitySubmitted', async msg => { ... })
```

**Example prompt:**
```
Emit a SupplierApproved event when the approve action runs.
Let NotificationService listen to it.
```

---

### `cds-remote` — External service integration

**Trigger phrases:** "external service", "API integration", "connect remote", "S/4HANA"

**What it does:** Implements the Calesi pattern:

```
mock implementation   →  fast local development
real implementation  →  production (RemoteService proxy)
package.json         →  [development] / [production] profile switch
```

**Example prompt:**
```
Connect to an external InventoryService REST API.
Use a mock during development.
```

---

### `fiori-page` — Add a Fiori Elements page

**Trigger phrases:** "add page", "new list report", "add object page"

**What it does:** Adds route + target to `manifest.json`:

```json
// ListReport
{ "pattern": "Suppliers:?query:", "name": "SuppliersList", "target": "SuppliersList" }

// ObjectPage
{ "pattern": "Suppliers({key}):?query:", "name": "SuppliersDetails", "target": "SuppliersDetails" }
```

**Example prompt:**
```
Add a ListReport and ObjectPage for Suppliers in the selected Fiori app directory.
```

---

### `wdi5-test` — Generate E2E tests

**Trigger phrases:** "add test", "write wdi5 test", "E2E test"

**What it does:** Generates Page Object + spec file following the project's existing pattern:

```
app/<app>/webapp/test/wdi5/
├── specs/          → Test scenarios (describe/it blocks)
└── pageobjects/    → Page Object actions (browser.asControl selectors)
```

**Example prompt:**
```
Write a wdi5 test that opens the Suppliers list, clicks Create,
fills in the name field, and saves.
```

---

## Hooks (Automatic)

Three hooks run automatically in the background when you edit files:

| Event | Hook | What it does |
|-------|------|-------------|
| Any file edit | **PreToolUse** | Blocks edits to `.env` and `wdi5.db` |
| Any `.cds` file saved | **PostToolUse** | Runs `cds compile` and shows syntax errors immediately |
| `schema.cds` saved | **PostToolUse (agent)** | Syncs CSV headers + adds missing i18n keys across all language files |

The schema.cds hook is especially useful — when you add a field, it automatically:
1. Updates the header row of the matching CSV seed file
2. Adds the missing `KEY = Value` entry to every `i18n*.properties` file

---

## i18n Support

Setup creates language files for every app directory automatically:

```
app/<app>/webapp/i18n/
├── i18n.properties        → Default (English)
├── i18n_en.properties     → English
├── i18n_de.properties     → German
└── i18n_tr.properties     → Turkish
```

Language list is stored in `.claude/i18n-config.json` and used by both the setup and the PostToolUse hook agent.

---

## Re-running Setup

If you add new entities or services, regenerate all config files:

```bash
npm run setup:claude
```

This regenerates `CLAUDE.md` and all `SKILL.md` files from the templates with updated project values. Existing i18n files are preserved.

---

## Tech Stack

- **Node.js** ^22
- **@sap/cds** — SAP Cloud Application Programming Model
- **SAP Fiori Elements** (`sap.fe.templates`) — ListReport + ObjectPage
- **OData v4** / SQLite
- **wdi5** — WebdriverIO + UI5 E2E testing
- **MTA** / Cloud Foundry — deployment
