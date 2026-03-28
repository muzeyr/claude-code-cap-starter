---
name: cds-auth
description: Adds role-based authorization to a CAP service. Sets up xs-security.json, @restrict annotations and mock users together. Use for "add auth", "define roles", "who can access", "authentication".
---

# cds-auth Skill

Authorization in CAP works across three layers. Configure all of them together.

```
CDS Annotations (@restrict)  ←  Who can access what?
    ↓
xs-security.json              ←  Which roles exist in Cloud Foundry?
    ↓
package.json (mocked)         ←  Which test users exist in development?
```

---

## Layer 1 — CDS Annotations

### Service level (most common)
```cds
// Only this role can access the entire service
service AdminService @(requires: 'admin') { ... }

// Multiple roles
service ReportService @(requires: ['admin', 'auditor']) { ... }

// Any logged-in user
service ProfileService @(requires: 'authenticated-user') { ... }

// Public (including anonymous)
service CatalogService @(requires: 'any') { ... }
```

### Entity level (granular control)
```cds
service AdminService @(requires: 'authenticated-user') {

  // Role + operation based restriction
  @restrict: [
    { grant: 'READ',              to: ['viewer', 'admin'] },
    { grant: ['CREATE', 'UPDATE'], to: 'admin' },
    { grant: 'DELETE',             to: 'admin' }
  ]
  entity Books as projection on my.Books;

  // Read-only — any authenticated user can view
  @readonly
  entity Authors as projection on my.Authors;
}
```

### Row level (instance-based) — advanced
```cds
// Users can only see data they created
@restrict: [
  { grant: 'READ', where: 'createdBy = $user' },
  { grant: 'WRITE', to: 'admin' }
]
entity MyOrders as projection on my.Orders;
```

### Action / Function authorization
```cds
service OrderService @(requires: 'authenticated-user') {
  entity Orders as projection on my.Orders;

  // Only admin can invoke
  @restrict: [{ grant: 'INVOKE', to: 'admin' }]
  action approveOrder(id: Integer) returns Orders;

  // Any authenticated user can invoke
  action cancelOrder(id: Integer) returns Orders;
}
```

---

## Layer 2 — xs-security.json (Production)

```json
{
  "xsappname": "{{PROJECT_NAME}}-${org}-${space}",
  "tenant-mode": "dedicated",
  "scopes": [
    {
      "name": "$XSAPPNAME.admin",
      "description": "Full administrative access"
    },
    {
      "name": "$XSAPPNAME.viewer",
      "description": "Read-only access"
    },
    {
      "name": "$XSAPPNAME.auditor",
      "description": "Audit log access"
    }
  ],
  "attributes": [],
  "role-templates": [
    {
      "name": "admin",
      "description": "Administrator — full CRUD",
      "scope-references": ["$XSAPPNAME.admin"]
    },
    {
      "name": "viewer",
      "description": "Viewer — read only",
      "scope-references": ["$XSAPPNAME.viewer"]
    },
    {
      "name": "auditor",
      "description": "Auditor — reports and audit logs",
      "scope-references": [
        "$XSAPPNAME.auditor",
        "$XSAPPNAME.viewer"
      ]
    }
  ]
}
```

---

## Layer 3 — package.json: Mock Users (Development)

Add to `package.json` → `"cds"` → `"[development]"` block:

```json
"[development]": {
  "auth": {
    "kind": "mocked",
    "users": {
      "alice": {
        "roles": ["admin"],
        "password": "alice"
      },
      "bob": {
        "roles": ["viewer"],
        "password": "bob"
      },
      "carol": {
        "roles": ["auditor", "viewer"],
        "password": "carol"
      },
      "anonymous": {}
    }
  }
}
```

---

## Test Commands

```bash
# Admin — full access
curl -u alice:alice http://localhost:4004/admin/Books

# Viewer — read only
curl -u bob:bob http://localhost:4004/admin/Books

# Anonymous — only 'any' services
curl http://localhost:4004/catalog/Books

# Unauthorized access test (expect 403)
curl -u bob:bob -X POST http://localhost:4004/admin/Books \
  -H "Content-Type: application/json" \
  -d '{"title":"Test"}'
```

---

## Checklist

- [ ] `srv/*.cds` → `@(requires:)` at service level
- [ ] `srv/*.cds` → `@restrict` at entity/action level (if needed)
- [ ] `xs-security.json` → scope + role-template
- [ ] `package.json` → `[development]` mock users (alice=admin, bob=viewer)
- [ ] Test: manual test with authorized + unauthorized user

---

## Role Design Guide

| Use case | Annotation | xs-security scope |
|----------|-----------|------------------|
| Public read | `@(requires: 'any')` | not needed |
| Authenticated read | `@(requires: 'authenticated-user')` | not needed |
| Custom role | `@(requires: 'admin')` | `$XSAPPNAME.admin` scope required |
| Row filter | `@restrict: [{ where: 'createdBy = $user' }]` | no role needed, user identity is enough |
| Multiple roles | `@(requires: ['admin', 'manager'])` | scope required for each |

**Warning:** `dummy` auth (`"auth": "dummy"`) disables all security checks in development. Never use in production.
