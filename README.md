# Claude Code CAP Starter: AI-Assisted SAP CAP Development with Structure and Stability

> A Claude Code configuration layer that makes AI-assisted development on SAP CAP projects consistent, context-aware, and production-safe — by encoding your architecture rules directly into the AI's working environment.

---

## The Problem: AI Coding Without Context Is Unpredictable

SAP CAP is an opinionated framework. It has a strict layering model — `db/` for data, `srv/` for services, `app/` for UI annotations. It has naming conventions, association rules, a three-layer authorization model, and a specific pattern for connecting external services. When you deviate from these patterns, the framework still runs — but the result becomes hard to maintain, hard to test, and fragile under change.

When you introduce an AI coding assistant like Claude Code into a CAP project without any context, you get an intelligent but uninformed collaborator. It will generate syntactically correct CDS. But it may:

- Put `@UI` annotations inside `db/schema.cds` instead of `app/`
- Expose every entity in one generic `AdminService` instead of bounded-context services
- Skip `xs-security.json` when adding a new role
- Forget to add i18n keys when creating a new field
- Use `SELECT *` in a service handler
- Mix business logic with service definitions

None of these are errors Claude invented. They are the same mistakes human developers make when they don't know the project's conventions. The solution is the same in both cases: **encode the rules, don't rely on memory.**

This is what `claude-code-cap-starter` does.

---

## The Idea: Teach Claude Your Architecture Once

Claude Code reads a `CLAUDE.md` file at the root of your project every time a session starts. This file is your project's constitution — it tells Claude what exists, where things live, and how they are organized.

But a static markdown file only goes so far. What you really want is for Claude to follow the *rules* of your architecture — not just know the directory names, but understand *why* they exist and *what to do* in each situation.

`claude-code-cap-starter` provides three mechanisms for this:

**1. Project Memory (`CLAUDE.md` + `.claude/memory/`)**
Generated from your actual project files. Claude knows your namespace, entity list, service path, app directory, and supported languages — without you re-explaining it in every session.

**2. Skill Templates (`.claude/templates/skills/`)**
Seven prompt templates, one for each common CAP development task. When you say "add a new entity", Claude doesn't guess — it follows a step-by-step guide that encodes the correct multi-file flow for your specific project.

**3. Automatic Hooks (`.claude/settings.json`)**
Three hooks that run in the background while you work. They validate CDS syntax on every save, prevent accidental edits to protected files, and automatically synchronize CSV seed headers and i18n files when the schema changes.

---

## Why This Makes Development More Stable

### 1. The AI follows the same rules every time

In a CAP project, adding a new entity correctly means touching six files:

```
db/schema.cds              ← entity definition
srv/<service>.cds          ← service projection
app/labels.cds             ← @title annotations
app/*/webapp/i18n/*.properties  ← labels for all languages
app/<app>/fiori-service.cds    ← ListReport + ObjectPage config
db/data/<namespace>-Entity.csv ← seed data
```

Without guidance, an AI assistant might touch two or three of these. With the `cds-entity` skill template, it touches all six — every time, in the correct order, with the correct patterns.

This is not about Claude being more capable. It is about removing ambiguity. A senior developer with a checklist is more consistent than a senior developer without one. The same principle applies here.

---

### 2. Violations are caught automatically, not in code review

The PostToolUse hook that runs `cds compile` on every `.cds` file save means syntax errors surface in seconds, not at the next build or code review. The agent-based hook that watches `schema.cds` for changes means a newly added field is automatically propagated to:

- The CSV seed file header row (so seed data doesn't silently break)
- Every `i18n*.properties` file for every supported language (so no field is untranslated at deploy time)

These are the kinds of mistakes that cost thirty minutes in a code review and thirty seconds to prevent. The hook prevents them.

---

### 3. Authorization is treated as a first-class concern

One of the most common stability issues in CAP projects is incomplete authorization. A developer adds a new service, tests it locally with mock users, and ships it — with `@requires: 'authenticated-user'` instead of properly scoped roles. The feature works, but the access control is wrong.

`claude-code-cap-starter` enforces a three-layer rule for every authorization change:

| Layer | File | Never skip because |
|-------|------|-------------------|
| CDS `@restrict` | `srv/*.cds` | This is what the runtime enforces |
| `xs-security.json` | project root | This is what BTP uses to assign roles |
| Mock users | `package.json` | Without this, you cannot test the auth locally |

The `cds-auth` skill template generates all three layers together. Skipping one requires actively overriding the template.

---

### 4. External service integration never blocks local development

The Calesi pattern — defining an external service, mocking it locally, and switching to a real destination in production via `package.json` profiles — is well-documented in CAP. But it is easy to skip the mock when time is short.

When you skip the mock, every developer who clones the repo and runs `cds watch` gets a connection error. Local development is blocked until they configure a destination or VPN.

The `cds-remote` skill template generates the mock alongside the real implementation as a single unit. They are not separate steps — they are the same task.

---

### 5. Project context survives session boundaries

Claude Code sessions are stateless by default. Every new session starts fresh. Without persistent context, you spend the first few minutes of every session re-orienting Claude to your project — what's the namespace, what's the service path, what entities exist.

The `.claude/memory/project_context.md` file stores this context persistently. The generated `CLAUDE.md` is loaded automatically by Claude Code at session start. You open a session and Claude already knows your project. No re-explanation needed.

---

## Architecture Overview

```
.claude/
├── setup.js                  → One-time setup: auto-detects project, generates all config
├── settings.json             → Hooks: file guard + CDS compile + CSV/i18n sync
├── i18n-config.json          → Supported languages (used by hooks and setup)
├── templates/
│   ├── CLAUDE.md.tpl         → Project context template (generates CLAUDE.md)
│   └── skills/
│       ├── cds-entity.tpl    → 6-file flow for adding an entity
│       ├── cds-service.tpl   → Service definition + handler + auth + mock users
│       ├── cds-auth.tpl      → 3-layer authorization setup
│       ├── cds-event.tpl     → Async event emit/on pattern
│       ├── cds-remote.tpl    → External service: mock + real + profile switch
│       ├── fiori-page.tpl    → manifest.json route + target
│       └── wdi5-test.tpl     → Page Object + spec file
└── memory/
    └── project_context.md    → Persistent project context for Claude
```

---

## Getting Started

### 1. Copy `.claude/` into your CAP project root

```bash
cp -r claude-code-cap-starter/.claude /your-cap-project/
```

### 2. Install and run setup

```bash
npm install
npm run setup:claude
```

Setup auto-detects your project structure from existing files:

| Source file | What is detected |
|-------------|-----------------|
| `package.json` | Project name, description, app directory |
| `db/schema.cds` | CDS namespace, entity list |
| `srv/*.cds` | Service name, URL path, file name |
| `app/` | App directory name |

It asks one question: which languages to support. Everything else is detected automatically.

### 3. Open Claude Code

```bash
claude
```

Claude now knows your full project context.

---

## Skills Reference

Skills are invoked through natural language. You do not need to remember command names.

| Skill | Example prompt | What it generates |
|-------|---------------|------------------|
| `cds-entity` | "Add a Supplier entity with name and country" | schema + projection + labels + i18n + UI + CSV |
| `cds-service` | "Add a SupplierService with admin role" | .cds definition + .js handler + xs-security + mock users |
| `cds-auth` | "Viewers can only read, editors can write" | @restrict annotations + xs-security.json + package.json |
| `cds-event` | "Emit SupplierApproved when the approve action runs" | emit in handler + on listener in target service |
| `cds-remote` | "Connect to an external InventoryService REST API" | mock + real + package.json profile switch |
| `fiori-page` | "Add a ListReport and ObjectPage for Suppliers" | manifest.json route + target entries |
| `wdi5-test` | "Write a test that opens Suppliers, clicks Create, fills name, saves" | Page Object + spec file |

---

## Automatic Hooks

| Trigger | Hook type | What happens |
|---------|-----------|-------------|
| Any file edit | PreToolUse | Blocks edits to `.env` and `wdi5.db` |
| Any `.cds` file saved | PostToolUse | `cds compile` runs — syntax errors shown immediately |
| `schema.cds` saved | PostToolUse (agent) | CSV headers synced + missing i18n keys added to all language files |

---

## SAP CAP Best Practices (Encoded in Every Skill)

### Layering — the non-negotiable rule

```
db/schema.cds      → entity definitions only. No annotations, no logic.
srv/*.cds          → service projections only. No @UI, no @title.
app/*.cds          → UI annotations only. No entity fields, no service logic.
```

Mixing these layers is the most common source of CAP projects becoming hard to navigate. Every skill template enforces this separation.

---

### Services: use-case oriented, not entity mirrors

```cds
// Correct — one service per bounded context
service TravelService @(path: '/travel') {
  entity Travels  as projection on travel.Travel;
  entity Bookings as projection on travel.Booking;
}

// Problematic — a generic service with everything
service AdminService {
  entity Travel    as projection on travel.Travel;
  entity Booking   as projection on travel.Booking;
  entity Airline   as projection on travel.Airline;
  entity Airport   as projection on travel.Airport;
  // no clear ownership, authorization becomes coarse
}
```

---

### Handler phases — each phase has one job

```js
// before  → validate inputs, check preconditions
// on      → execute business logic, write to DB
// after   → post-processing, emit events

this.before('CREATE', 'Travels', (req) => {
  if (!req.data.description) req.reject(400, 'Description is required');
});

this.on('CREATE', 'Travels', async (req) => {
  const result = await INSERT.into(Travel).entries(req.data);
  return result;
});

this.after('CREATE', 'Travels', async (data, req) => {
  await this.emit('TravelCreated', { travelID: data.ID });
});
```

---

### Authorization — three layers, always together

```cds
entity Travels @(
  restrict: [
    { grant: ['READ'],                    to: 'TravelViewer' },
    { grant: ['READ','WRITE'],            to: 'TravelEditor' },
    { grant: ['READ','WRITE','DELETE'],   to: 'TravelAdmin' }
  ]
) as projection on travel.Travel;
```

This CDS annotation is layer one. Without the matching `xs-security.json` role and `package.json` mock user, it cannot be tested and it will not deploy correctly to BTP.

---

### Naming conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Namespace | `reverse.domain.app` | `sap.fe.cap.travel` |
| Entity name | `PascalCase` | `BookingStatus` |
| Property name | `camelCase` | `totalPrice` |
| Service name | `PascalCase` + `Service` | `TravelService` |
| CSV seed file | `<namespace>-<Entity>.csv` | `sap.fe.cap.travel-Travel.csv` |
| i18n key | `<Entity>_<Property>` | `Travel_totalPrice` |

---

### i18n — every field in every language

```properties
# i18n.properties (default, English)
Travel_totalPrice=Total Price
Travel_status=Status

# i18n_de.properties
Travel_totalPrice=Gesamtpreis
Travel_status=Status

# i18n_tr.properties
Travel_totalPrice=Toplam Fiyat
Travel_status=Durum
```

The PostToolUse hook adds missing keys automatically when `schema.cds` changes. This prevents silent untranslated fields appearing in production UIs.

---

### Testing — Page Objects are mandatory

```js
// Correct — selector lives in the Page Object
class TravelListPage {
  async clickCreate() {
    const btn = await browser.asControl({
      selector: { id: 'CreateButton', viewName: 'TravelList' }
    });
    await btn.press();
  }
}

// Incorrect — selector inline in spec (breaks when UI changes)
it('creates a travel', async () => {
  const btn = await browser.asControl({ selector: { id: 'CreateButton' } });
  await btn.press();
});
```

---

## Clean Code Rules — Quick Reference

| Rule | Why it matters |
|------|---------------|
| One responsibility per `.cds` file | Prevents annotation and logic from leaking between layers |
| No `SELECT *` in handlers | Prevents over-fetching and exposes only intentional data |
| Bounded-context services | Authorization scoping, clear ownership, smaller surface area |
| Three-layer auth always | CDS alone doesn't protect BTP-deployed apps without xs-security.json |
| Two paths for remote services | Skipping mock blocks all local development |
| i18n keys in all languages | Prevents untranslated labels in production Fiori apps |
| Page Objects for all selectors | Single point of change when UI IDs change |
| Events in service definitions | Schema is for structure, not communication contracts |

---

## Re-running Setup

When you add new entities or services, regenerate CLAUDE.md and skill files to keep Claude's context current:

```bash
npm run setup:claude
```

Existing i18n files and hook configurations are preserved. Only `CLAUDE.md` and skill files are regenerated.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Runtime | Node.js ^22 |
| Framework | @sap/cds — SAP Cloud Application Programming Model |
| UI | SAP Fiori Elements (`sap.fe.templates`) |
| Protocol | OData v4 |
| Database | SQLite (development) / SAP HANA (production) |
| Testing | wdi5 (WebdriverIO + UI5 integration) |
| Deployment | MTA / Cloud Foundry on SAP BTP |
| AI Tooling | Claude Code (Anthropic) |

---

## Conclusion

The core argument of this project is simple: an AI coding assistant is only as consistent as the context it has been given. In a framework as structured as SAP CAP, that context needs to cover not just file locations but architectural rules, naming conventions, multi-file flows, and the reasoning behind them.

`claude-code-cap-starter` is the answer to the question: *what would it look like if Claude had been onboarded to your CAP project properly?*

The answer is fewer forgotten i18n keys, fewer authorization gaps, fewer schema annotations in the wrong file, and fewer broken local environments from missing mocks. Not because the AI got smarter — but because the rules are written down and the AI follows them.

That is what stable AI-assisted development looks like in practice.
