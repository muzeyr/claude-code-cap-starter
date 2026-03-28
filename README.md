# claude-code-cap-starter

A Claude Code configuration layer for SAP CAP (Cloud Application Programming Model) projects. Provides context-aware AI assistance through automated hooks, skill templates, and project memory — so Claude understands your namespace, entities, services, and Fiori app structure without re-explanation.

---

## What This Is

This starter is **not a CAP application** — it is the `.claude/` tooling layer you drop into any CAP project to make Claude Code production-aware. After running setup, Claude knows:

- Your CDS namespace and entity list
- Your service name, path, and file
- Your app directory and i18n languages
- The rules for modifying each layer of the stack

---

## Quick Start

```bash
# 1. Copy this .claude/ directory into your CAP project root
# 2. Install dependencies
npm install

# 3. Run setup (auto-detects your project structure)
npm run setup:claude

# 4. Open Claude Code
claude
```

Setup auto-detects from your existing files:

| Source | What is detected |
|--------|-----------------|
| `package.json` | Project name, description, app directory |
| `db/schema.cds` | CDS namespace, entity list |
| `srv/*.cds` | Service name, URL path, file name |
| `app/` | App directory name |

---

## Project Structure

```
.claude/
├── setup.js                  → One-time setup script (auto-detects project)
├── settings.json             → Hooks: file guard + CDS syntax check + i18n sync
├── i18n-config.json          → Supported languages list
├── templates/
│   ├── CLAUDE.md.tpl         → Project context template
│   └── skills/
│       ├── cds-entity.tpl    → Add entity to data model
│       ├── cds-service.tpl   → Create a new OData service
│       ├── cds-auth.tpl      → Role-based authorization
│       ├── cds-event.tpl     → Async events between services
│       ├── cds-remote.tpl    → External service integration
│       ├── fiori-page.tpl    → Add Fiori Elements page
│       └── wdi5-test.tpl     → E2E test generation
└── memory/
    └── project_context.md    → Persistent project context for Claude
```

---

## SAP CAP Development Best Practices

These rules are baked into every skill template and hook. Follow them consistently.

### Data Model

**Separation of concerns:**
- `db/schema.cds` — entity definitions only, no service logic
- `srv/*.cds` — projections and service exposure only
- `app/*.cds` — UI annotations (`@title`, `@UI.LineItem`, etc.) only

**Naming:**
- Entities: `PascalCase` (e.g. `BookingStatus`)
- Properties: `camelCase` (e.g. `totalPrice`)
- Namespace: `reverse.domain.app` (e.g. `sap.fe.cap.travel`)
- CSV seed files: `<namespace>-<Entity>.csv` (exact match with entity name)

**Associations:**
- Always define both sides of an association
- Use `Composition` for parent-child (e.g. Travel → Booking)
- Use `Association` for references (e.g. Booking → Airline)
- Managed associations use `to` keyword; backlinks use `on`

**Never:**
- Define `@title` or UI annotations inside `db/schema.cds`
- Add business logic inside entity definitions
- Hardcode enum values — use a separate status entity with a code list

---

### Services

**Design principle:** Services are use-case oriented, not entity mirrors.

```cds
// Good — one service per bounded context
service TravelService @(path: '/travel') {
  entity Travels as projection on travel.Travel;
  entity Bookings as projection on travel.Booking;
}

// Bad — exposing every entity in one generic AdminService
service AdminService {
  entity Travel     as projection on travel.Travel;
  entity Booking    as projection on travel.Booking;
  entity Airline    as projection on travel.Airline;
  entity Airport    as projection on travel.Airport;
  // ...every entity in the schema
}
```

**Handler phases:**
- `before` — input validation, authorization checks
- `on` — business logic, data manipulation
- `after` — post-processing, outbound events

**Never:**
- Put DB queries inside `before` handlers (use `on`)
- Use `SELECT *` — always project only needed fields
- Mix service definitions and business logic in the same `.cds` file

---

### Authorization

Always define authorization in three synchronized layers:

| Layer | File | Purpose |
|-------|------|---------|
| CDS annotations | `srv/*.cds` | Declare who can do what |
| Role definitions | `xs-security.json` | CF role templates for production |
| Mock users | `package.json` | `alice` (admin), `bob` (viewer) for dev |

```cds
// Entity-level restriction — most granular
entity Travels @(
  restrict: [
    { grant: ['READ'],             to: 'TravelViewer' },
    { grant: ['READ','WRITE'],     to: 'TravelEditor' },
    { grant: ['READ','WRITE','DELETE'], to: 'TravelAdmin' }
  ]
) as projection on travel.Travel;
```

**Rules:**
- Never use `@requires: 'authenticated-user'` as a substitute for real roles
- Always pair `xs-security.json` changes with mock user updates in `package.json`
- Row-level filtering goes in `before READ` handlers, not CDS annotations

---

### Events and Async Communication

**Sync vs async decision:**

| Use | When |
|-----|------|
| `action` (sync) | Caller needs the result immediately |
| `emit` (async) | Fire-and-forget, decoupled notification |

```js
// Emitting — Service A
async function submitTravel(req) {
  const travel = await UPDATE(Travel).set({ status: 'A' }).where({ ID: req.params.ID });
  await this.emit('TravelSubmitted', { travelID: req.params.ID });
}

// Listening — Service B
const travelSvc = await cds.connect.to('TravelService');
travelSvc.on('TravelSubmitted', async ({ data }) => {
  await INSERT.into(Notification).entries({ ref: data.travelID, type: 'submit' });
});
```

**Never:**
- Define events inside `db/schema.cds` — events belong in service definitions
- Await emitted events from a listener (creates circular coupling)

---

### External Services (Calesi Pattern)

Always implement two paths: mock (dev) and real (prod):

```
srv/
├── external/
│   ├── InventoryService.cds       → CDS definition (structure contract)
│   ├── inventory-mock.js          → Local mock implementation
│   └── inventory-remote.js        → Real RemoteService proxy
```

```json
// package.json — profile-based switching
{
  "cds": {
    "[development]": {
      "requires": {
        "InventoryService": { "impl": "./srv/external/inventory-mock.js" }
      }
    },
    "[production]": {
      "requires": {
        "InventoryService": { "kind": "odata", "credentials": { "destination": "INVENTORY" } }
      }
    }
  }
}
```

**Never:**
- Hardcode external service URLs — always use destinations or environment variables
- Skip the mock implementation — it blocks local development if omitted

---

### Fiori Elements

**manifest.json route rules:**
- `entitySet` must exactly match the service projection name (case-sensitive)
- Route `id` must be unique across all routes
- ListReport pattern: `"Entities:?query:"`
- ObjectPage pattern: `"Entities({key}):?query:"`

**Annotation files (`app/*.cds`):**
- One annotation file per entity (e.g. `travel-annotations.cds`)
- Never put `@UI` annotations in `db/schema.cds` or `srv/*.cds`
- Keep `@title` in `app/labels.cds`, `@UI.LineItem` / `@UI.FieldGroup` in entity annotation file

---

### i18n

- Always add i18n keys for every new entity and field
- Key format: `<Entity>_<Property>` (e.g. `Travel_totalPrice`)
- All keys must exist in all language files — the hook auto-adds missing keys
- Default values in `i18n.properties` must be English

```properties
# i18n.properties
Travel_totalPrice=Total Price
Travel_status=Status

# i18n_de.properties
Travel_totalPrice=Gesamtpreis
Travel_status=Status
```

---

### Testing (wdi5)

- One spec file per user scenario (not per entity)
- All browser interactions go through Page Object methods — never inline selectors in specs
- Selector format: `browser.asControl({ selector: { id: 'exact-id', viewName: 'ViewName' } })`
- Tests must be independent — no shared state between `it` blocks

```js
// Good — Page Object encapsulates selector
class TravelListPage {
  async clickCreateButton() {
    const btn = await browser.asControl({ selector: { id: 'CreateButton', viewName: 'TravelList' } });
    await btn.press();
  }
}

// Bad — selector inline in spec
it('creates travel', async () => {
  const btn = await browser.asControl({ selector: { id: 'CreateButton' } });
  await btn.press();
});
```

---

## Hooks (Automatic)

Three hooks run automatically when you edit files:

| Event | Hook | What it does |
|-------|------|-------------|
| Any file edit | PreToolUse | Blocks edits to `.env` and `wdi5.db` |
| Any `.cds` file saved | PostToolUse | Runs `cds compile` — shows syntax errors immediately |
| `schema.cds` saved | PostToolUse (agent) | Syncs CSV headers + adds missing i18n keys to all language files |

---

## Skills Reference

Skills are prompt templates that guide Claude through common CAP tasks. Invoke them in natural language.

| Skill | Trigger | What it generates |
|-------|---------|------------------|
| `cds-entity` | "add entity", "new table" | schema.cds + projection + labels + i18n + UI + CSV |
| `cds-service` | "add service", "new API" | .cds definition + .js handler + xs-security + mock users |
| `cds-auth` | "add auth", "define roles" | @restrict annotations + xs-security.json + package.json |
| `cds-event` | "add event", "async notification" | emit pattern + listener implementation |
| `cds-remote` | "external service", "S/4HANA" | mock + real + package.json profile switch |
| `fiori-page` | "add page", "list report" | manifest.json route + target |
| `wdi5-test` | "add test", "E2E test" | Page Object + spec file |

---

## Clean Code Rules Summary

| Rule | Context |
|------|---------|
| One responsibility per `.cds` file | schema = model, srv = service, app = UI |
| No `SELECT *` in service handlers | always project needed fields |
| Namespace + PascalCase for entities | `sap.fe.cap.travel.Booking` |
| camelCase for all properties | `totalPrice`, `statusCode` |
| Always define both sides of associations | forward + backlink |
| Three-layer auth: CDS + xs-security + mock | never skip any layer |
| Two paths for remote services: mock + real | never skip mock |
| i18n keys in all language files | hook enforces this automatically |
| Page Objects for all wdi5 selectors | never inline selectors in specs |
| Events belong in service definitions | never in db/schema.cds |

---

## Re-running Setup

If you add new entities or services, regenerate CLAUDE.md and skill files:

```bash
npm run setup:claude
```

Existing i18n files and hook configurations are preserved.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Runtime | Node.js ^22 |
| Framework | @sap/cds (SAP CAP) |
| UI | SAP Fiori Elements (`sap.fe.templates`) |
| Protocol | OData v4 |
| Database | SQLite (dev) / HANA (prod) |
| Testing | wdi5 (WebdriverIO + UI5) |
| Deployment | MTA / Cloud Foundry (BTP) |
| AI Tooling | Claude Code + Claude Code Starter |
