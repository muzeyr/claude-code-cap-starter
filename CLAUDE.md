# Claude

CAP flight demo scenario

## Architecture

```
uzi-cap/
├── db/schema.cds          → Data model (namespace: sap.fe.cap.travel)
├── srv/analytics-service.cds   → OData v4 AnalyticsService
├── app/travel_processor/       → Fiori Elements application
│   └── webapp/test/wdi5/
│       ├── specs/         → wdi5 test scenarios
│       └── pageobjects/   → Page Object Model
├── index.cds              → Main CDS entry point
└── index.js               → Express server
```

## Data Model (namespace: sap.fe.cap.travel)

- **Travel**
- **Booking**
- **BookingSupplement**
- **BookingStatus**
- **TravelStatus**

## Services

- **AnalyticsService**: OData v4, `//analytics/`

## Database

- SQLite (`wdi5.db`) — both development and production
- Schema is created with `cds deploy`

## Commands

```bash
npm run watch         # Development: cds watch (hot reload)
npm start             # cds deploy && cds run
npm run setup:claude  # Re-run Claude Code setup
```

## Testing (wdi5)

- Framework: wdi5 (WebdriverIO + UI5 integration)
- Pattern: Page Object Model
- Specs: `app/travel_processor/webapp/test/wdi5/specs/`
- Page objects: `app/travel_processor/webapp/test/wdi5/pageobjects/`

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
