# {{PROJECT_NAME}}

{{PROJECT_DESCRIPTION}}

## Architecture

```
{{PROJECT_DIR}}/
├── db/schema.cds          → Data model (namespace: {{NAMESPACE}})
├── srv/{{SERVICE_FILE}}   → OData v4 {{SERVICE_NAME}}
├── app/{{APP_DIR}}/       → Fiori Elements application
│   └── webapp/test/wdi5/
│       ├── specs/         → wdi5 test scenarios
│       └── pageobjects/   → Page Object Model
├── index.cds              → Main CDS entry point
└── index.js               → Express server
```

## Data Model (namespace: {{NAMESPACE}})

{{ENTITY_LIST}}

## Services

- **{{SERVICE_NAME}}**: OData v4, `/{{SERVICE_PATH}}/`

## Database

- SQLite (`wdi5.db`) — both development and production
- Schema is created with `cds deploy`

## SAP CAP & Node.js Global Rules

- **Code Style:** Use CommonJS (`require` / `module.exports`) by default for CAP Node.js services.
- **Error Handling:** Always use `req.error(code, msg)` instead of `throw new Error(...)` to let CAP handle messages.
- **Transactions:** Always wrap database operations in `cds.tx(req)` to maintain transactional consistency.
- **Entity Naming:** Entity names should always be **PascalCase Plurals** (e.g. `Books`, `Reviews`).
- **i18n / UI Texts:** Do not hardcode UI text strings. Always use `@title: '{i18n>KEY}'` in `app/labels.cds` and add pairs to `i18n.properties` files.
- **Validation:** Use CDS annotations (`@assert.range`, `@mandatory`) in `.cds` files before writing manual JS validation.

## Commands

```bash
npm install
npm run setup:claude  # Re-run Claude Code setup
```

## Using `.claude`

This project contains the Claude Code tooling layer for SAP CAP. It is not a full runnable CAP application by itself.

- Run `npm run setup:claude` after copying `.claude/` into a CAP project root.
- Open Claude Code with `claude` once setup is complete.
- Use `.claude/templates/skills/*/SKILL.md` as the skill reference for CAP development.

## Testing (wdi5)

- Framework: wdi5 (WebdriverIO + UI5 integration)
- Pattern: Page Object Model
- Specs: `app/{{APP_DIR}}/webapp/test/wdi5/specs/`
- Page objects: `app/{{APP_DIR}}/webapp/test/wdi5/pageobjects/`

## Tech Stack

- Node.js ^22
- @sap/cds
- SAP Fiori Elements (`sap.fe.templates`)
- OData v4 / SQLite
- wdi5 (E2E tests)
- MTA / Cloud Foundry (deployment)

## Communication Preference

- English
- Focus on code and solutions, not explanations
