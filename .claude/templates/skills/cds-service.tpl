---
name: cds-service
description: Adds a new CAP service. Use-case oriented design, role-based authorization, projection, actions, events and handler skeleton. Use for "add service", "new service", "add API".
---

# cds-service Skill

In CAP, every service is specific to a use case ("use case-oriented service"). Not just `.cds` — generate the handler `.js`, authorization, and mock users all together.

## CAP Service Design Principles

- **Each service targets one user group** → AdminService (admin), CatalogService (anonymous), ReviewsService (authenticated)
- **Service = interface** → projection of domain entities, business logic in the handler
- **Role → at service or entity level** → `@(requires:)` or `@restrict`
- **Action** → non-CRUD operations (submit, approve, cancel)
- **Event** → async notifications (other services can listen)

---

## Files to Edit

```
db/schema.cds                ← 0. READ FIRST — get namespace and entity names from here
srv/{{SERVICE_FILE}}         ← 1. Service definition (CDS)
srv/{{SERVICE_HANDLER}}      ← 2. Handler (JS)
xs-security.json             ← 3. Role definitions (prod)
package.json [cds.requires]  ← 4. Mock users (dev)
app/services.cds             ← 5. Service using reference (if needed)
```

> **STRICT RULES:**
> - Read `db/schema.cds` before writing the service file → get namespace and entity names from there.
> - `@title` and i18n annotations go in `app/labels.cds` as annotate blocks — not inline in schema.

---

## 1 — srv/{{SERVICE_FILE}} (Service Definition)

### Scenario A: Admin service (full access)
```cds
// Get namespace from db/schema.cds
using { {{NAMESPACE}} as my } from '../db/schema';

/**
 * {{SERVICE_DESCRIPTION}}
 * Target users: {{TARGET_USER_GROUP}}
 */
service {{SERVICE_NAME}} @(requires: '{{REQUIRED_ROLE}}') {

  // Read-write entity — only accessible to this role
  entity {{MAIN_ENTITY}} as projection on my.{{MAIN_ENTITY}};

  // Read-only companion entity
  @readonly
  entity {{COMPANION_ENTITY}} as projection on my.{{COMPANION_ENTITY}};

  // Custom action — non-CRUD business operation
  action submit{{MAIN_ENTITY}}(id: Integer) returns {{MAIN_ENTITY}};

  // Async event — other services can listen
  event {{MAIN_ENTITY}}Submitted {
    id      : Integer;
    by      : String;
    at      : DateTime;
  }
}
```

### Scenario B: Public catalog service
```cds
using { {{NAMESPACE}} as my } from '../db/schema';

service CatalogService @(requires: 'any') {

  @readonly
  entity {{MAIN_ENTITY}} as projection on my.{{MAIN_ENTITY}} {
    ID, title, price, currency_code  // only needed fields
  }
}
```

### Scenario C: Multiple roles, entity-level restrict
```cds
service {{SERVICE_NAME}} @(requires: 'authenticated-user') {

  @restrict: [
    { grant: 'READ',            to: ['viewer', 'admin'] },
    { grant: ['WRITE', 'DELETE'], to: 'admin' }
  ]
  entity {{MAIN_ENTITY}} as projection on my.{{MAIN_ENTITY}};
}
```

---

## 2 — srv/{{SERVICE_HANDLER}} (Handler)

```js
const cds = require('@sap/cds/lib')

module.exports = class {{SERVICE_NAME}} extends cds.ApplicationService {
  async init () {

    const { {{MAIN_ENTITY}} } = this.entities

    // ── Validation (before) ──────────────────────────────────────────
    this.before('CREATE', {{MAIN_ENTITY}}, req => {
      const { /* field */ } = req.data
      // if (!field) return req.error(400, 'Field is required')
    })

    // ── Business Logic (on) ──────────────────────────────────────────
    this.on('submit{{MAIN_ENTITY}}', async req => {
      const { id } = req.data
      const tx = cds.tx(req)

      const item = await tx.run(SELECT.one.from({{MAIN_ENTITY}}).where({ ID: id }))
      if (!item) return req.error(404, `{{MAIN_ENTITY}} ${id} not found`)

      // business logic...

      // emit async event
      await this.emit('{{MAIN_ENTITY}}Submitted', {
        id,
        by: req.user.id,
        at: new Date().toISOString()
      })

      return item
    })

    // ── Post-processing (after) ──────────────────────────────────────
    this.after('READ', {{MAIN_ENTITY}}, (items) => {
      // enrich results, add computed fields
    })

    // ── Error handling ───────────────────────────────────────────────
    this.on('error', (err, req) => {
      console.error(`[{{SERVICE_NAME}}] ${err.message}`)
    })

    return super.init()
  }
}
```

---

## 3 — xs-security.json (Production Roles)

Add to existing `xs-security.json`:

```json
{
  "scopes": [
    {
      "name": "$XSAPPNAME.{{REQUIRED_ROLE}}",
      "description": "{{SERVICE_DESCRIPTION}} — full access"
    },
    {
      "name": "$XSAPPNAME.{{REQUIRED_ROLE}}-viewer",
      "description": "{{SERVICE_DESCRIPTION}} — read only"
    }
  ],
  "role-templates": [
    {
      "name": "{{REQUIRED_ROLE}}",
      "description": "{{SERVICE_NAME}} administrator role",
      "scope-references": ["$XSAPPNAME.{{REQUIRED_ROLE}}"]
    },
    {
      "name": "{{REQUIRED_ROLE}}-viewer",
      "description": "{{SERVICE_NAME}} viewer role",
      "scope-references": ["$XSAPPNAME.{{REQUIRED_ROLE}}-viewer"]
    }
  ]
}
```

---

## 4 — package.json [cds.requires] — Mock Users (Development)

Add to `package.json` → `"cds"` block:

```json
"[development]": {
  "auth": {
    "kind": "mocked",
    "users": {
      "alice": {
        "roles": ["{{REQUIRED_ROLE}}"],
        "password": "alice"
      },
      "bob": {
        "roles": ["{{REQUIRED_ROLE}}-viewer"],
        "password": "bob"
      },
      "anonymous": {}
    }
  }
}
```

Test: `curl -u alice:alice http://localhost:4004/{{SERVICE_PATH}}/{{MAIN_ENTITY}}`

---

## 5 — app/services.cds (Fiori reference)

```cds
using from '../srv/{{SERVICE_FILE}}';
```

---

## Checklist

- [ ] Read `db/schema.cds` → get namespace and entity names
- [ ] `srv/{{SERVICE_FILE}}` → service + `@(requires:)` + entities + actions + events
- [ ] `srv/{{SERVICE_HANDLER}}` → before/on/after handlers + error handler
- [ ] `xs-security.json` → scope + role-template (prod)
- [ ] `package.json` → mocked auth + test users (dev)

---

## CAP Service Best Practices

| Decision | Rule |
|----------|------|
| How many services? | One service per use case (admin / catalog / reviews separate) |
| Where to put auth? | `@(requires:)` at service level first, `@restrict` at entity/action level for detail |
| `any` vs role | Public read → `any`, writes always require a role |
| When to use Action? | Non-CRUD business operations (approve, submit, cancel) |
| When to use Event? | When other services need to react (loose coupling) |
| Handler phases | `this.before` → validation, `this.on` → business logic, `this.after` → enrichment |
| Error | `req.error(code, msg)` — do not throw, CAP handles the message |
