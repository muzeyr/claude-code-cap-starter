---
name: cds-event
description: Defines CAP async events and adds handlers. emit/on pattern for loose coupling between services. Use for "add event", "async notification", "inter-service communication", "listen to event".
---

# cds-event Skill

In CAP, sync requests and async events use the same handler syntax. Any service can listen to another service.

## When to Use Event vs Action?

| | Action (sync) | Event (async) |
|-|---------------|---------------|
| **Waits for response?** | Yes | No |
| **Other services listen?** | No | Yes |
| **Example** | `submitOrder` | `OrderPlaced`, `StockUpdated` |
| **Coupling** | Tight | Loose |

---

## 1 — Event Definition in Service CDS

```cds
service {{SERVICE_NAME}} @(requires: '{{REQUIRED_ROLE}}') {
  entity {{MAIN_ENTITY}} as projection on my.{{MAIN_ENTITY}};

  // Sync action — waits for result
  action submit{{MAIN_ENTITY}}(id: Integer) returns {{MAIN_ENTITY}};

  // Async event — fired, whoever listens will receive it
  event {{MAIN_ENTITY}}Submitted {
    id          : Integer;
    status      : String;
    submittedBy : String;
    submittedAt : DateTime;
  }

  event {{MAIN_ENTITY}}Cancelled {
    id     : Integer;
    reason : String;
  }
}
```

---

## 2 — Handler: Emitting Events (emit)

```js
// srv/{{SERVICE_HANDLER}}
const cds = require('@sap/cds/lib')

module.exports = class {{SERVICE_NAME}} extends cds.ApplicationService {
  async init () {
    const { {{MAIN_ENTITY}} } = this.entities

    // Action handler — business logic + emit event
    this.on('submit{{MAIN_ENTITY}}', async req => {
      const { id } = req.data
      const tx = cds.tx(req)

      // 1. business logic
      await tx.run(UPDATE({{MAIN_ENTITY}}).set({ status: 'submitted' }).where({ ID: id }))

      // 2. emit async event (fire-and-forget)
      await this.emit('{{MAIN_ENTITY}}Submitted', {
        id,
        status:      'submitted',
        submittedBy: req.user.id,
        submittedAt: new Date().toISOString()
      })

      return tx.run(SELECT.one.from({{MAIN_ENTITY}}).where({ ID: id }))
    })

    return super.init()
  }
}
```

---

## 3 — Listening in Another Service (on)

```js
// srv/notification-service.js — another service listening to this event
const cds = require('@sap/cds/lib')

module.exports = class NotificationService extends cds.ApplicationService {
  async init () {

    // Connect to {{SERVICE_NAME}} and listen for events
    const {{SERVICE_NAME_VAR}} = await cds.connect.to('{{SERVICE_NAME}}')

    {{SERVICE_NAME_VAR}}.on('{{MAIN_ENTITY}}Submitted', async msg => {
      const { id, submittedBy, submittedAt } = msg.data
      console.log(`[Notification] {{MAIN_ENTITY}} ${id} submitted by ${submittedBy}`)

      // send email, write log, trigger another system...
    })

    // Also listen for cancellation event
    {{SERVICE_NAME_VAR}}.on('{{MAIN_ENTITY}}Cancelled', async msg => {
      const { id, reason } = msg.data
      console.log(`[Notification] {{MAIN_ENTITY}} ${id} cancelled: ${reason}`)
    })

    return super.init()
  }
}
```

---

## 4 — Framework-level Event Listening (cds.db, cds.on)

```js
// Add a global handler to all services during bootstrap
cds.on('served', async services => {
  for (const svc of Object.values(services)) {
    svc.after('CREATE', '*', (_, req) => {
      console.log(`[Audit] ${req.user.id} created in ${svc.name}`)
    })
  }
})

// Monitor all queries at database level
cds.db.before('*', req => {
  console.log(`[DB] ${req.event} on ${req.target?.name}`)
})
```

---

## 5 — Messaging (SAP Event Mesh / BTP)

```js
// package.json → cds.requires
{
  "messaging": {
    "[development]": { "kind": "file-based-messaging" },
    "[production]": {
      "kind": "enterprise-messaging",
      "publishPrefix": "{{NAMESPACE}}/",
      "subscribePrefix": "+"
    }
  }
}
```

```js
// In service handler — publish to messaging service
const messaging = await cds.connect.to('messaging')
await messaging.emit('{{NAMESPACE}}/{{MAIN_ENTITY}}/submitted', req.data)
```

---

## Checklist

- [ ] `srv/*.cds` → `event EventName { ... }` definition inside service
- [ ] Handler `.js` → `this.emit('EventName', data)` inside action
- [ ] Listener service → `cds.connect.to()` + `.on('EventName', handler)`
- [ ] Development: `file-based-messaging` (writes to file, no message broker needed)
- [ ] Production: `enterprise-messaging` (SAP Event Mesh)

---

## Sync vs Async Decision Tree

```
Does the user wait for a result?
├─ Yes → Action (sync) → this.on('actionName', req => {...})
└─ No →
    Will other services react?
    ├─ Yes → Event (async) → this.emit('EventName', data)
    └─ No → after() handler is sufficient
```
