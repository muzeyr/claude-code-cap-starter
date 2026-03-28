---
name: fiori-page
description: Adds a new Fiori Elements route and target to manifest.json.
---

# fiori-page Skill

Adds a new route and target to `app/{{APP_DIR}}/webapp/manifest.json`.

## Patterns

### New ListReport
```json
// routes:
{ "pattern": "Items:?query:", "name": "ItemsList", "target": "ItemsList" }

// targets:
"ItemsList": {
    "type": "Component", "id": "ItemsList",
    "name": "sap.fe.templates.ListReport",
    "options": { "settings": { "entitySet": "Items", "initialLoad": true } }
}
```

### New ObjectPage
```json
// routes:
{ "pattern": "Items({key}):?query:", "name": "ItemsDetails", "target": "ItemsDetails" }

// targets:
"ItemsDetails": {
    "type": "Component", "id": "ItemsDetails",
    "name": "sap.fe.templates.ObjectPage",
    "options": { "settings": { "entitySet": "Items" } }
}
```

## Rules

- `entitySet` → must match the projection name in {{SERVICE_NAME}}
- `id` must be unique
- Preserve valid JSON
