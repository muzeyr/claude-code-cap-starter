# Claude

CAP flight demo scenario

## Architecture

```
<project>/
├── db/schema.cds          → Data model
├── srv/<service>.cds      → OData v4 service definition
├── app/<app_dir>/         → Fiori Elements application
│   └── webapp/test/wdi5/
│       ├── specs/         → wdi5 test scenarios
│       └── pageobjects/   → Page Object Model
├── index.cds              → Main CDS entry point
└── index.js               → Express server
```

## Data Model

- **EntityA**
- **EntityB**
- **Status**

## Services

- **<ServiceName>**: OData v4, `/path/`

## Database

- SQLite (`wdi5.db`) — both development and production
- Schema is created with `cds deploy`

## Commands

```bash
npm install
npm run setup:claude  # Re-run Claude Code setup
```

## Using `.claude`

This repository contains the Claude Code helper layer for SAP CAP. It is not a full CAP application by itself.

- Use `npm run setup:claude` to refresh project context and regenerate skill docs.
- Open Claude Code with `claude` after setup.
- The `.claude/` folder provides hooks, templates, and persistent memory for CAP development.

## Testing (wdi5)

- Framework: wdi5 (WebdriverIO + UI5 integration)
- Pattern: Page Object Model
- Specs: `app/<app_dir>/webapp/test/wdi5/specs/`
- Page objects: `app/<app_dir>/webapp/test/wdi5/pageobjects/`

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
