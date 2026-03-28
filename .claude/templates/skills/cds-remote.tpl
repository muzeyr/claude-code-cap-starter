---
name: cds-remote
description: Adds external service integration (Calesi pattern). Mock + real implementation, cds.connect.to, RemoteService proxy. Use for "external service", "API integration", "connect remote service", "S/4HANA connection".
---

# cds-remote Skill

External services in CAP are integrated using the "Calesi pattern": define a CAP-level interface first, develop with a mock, then connect the real implementation in production.

## Calesi Pattern (from CAP docs)

```
1. Define the service interface (CDS)
2. Write a mock implementation (fast development)
3. Write the real implementation (production)
4. Select profile-based in package.json
```

---

## 1 — External Service Definition (CDS)

```cds
// srv/external/{{EXTERNAL_SERVICE_NAME}}.cds
// Import external service or define manually

// A: Import from external CDS file (S/4HANA, BTP services)
using { {{EXTERNAL_SERVICE_NAME}} } from './external/{{EXTERNAL_SERVICE_FILE}}';

// B: Manual definition (REST API, simple services)
service {{EXTERNAL_SERVICE_NAME}} {
  entity {{EXTERNAL_ENTITY}} {
    key ID   : String;
    name     : String;
    status   : String;
  }
  action trigger(id: String) returns Boolean;
}
```

---

## 2 — Mock Implementation (Development)

```js
// srv/external/{{EXTERNAL_SERVICE_NAME}}-mock.js
const cds = require('@sap/cds/lib')

module.exports = class {{EXTERNAL_SERVICE_NAME}}Mock extends cds.Service {
  async init () {

    // READ mock — return fake data
    this.on('READ', '{{EXTERNAL_ENTITY}}', () => [
      { ID: '1', name: 'Mock Item 1', status: 'active' },
      { ID: '2', name: 'Mock Item 2', status: 'inactive' },
    ])

    // Action mock
    this.on('trigger', req => {
      const { id } = req.data
      console.log(`[Mock] {{EXTERNAL_SERVICE_NAME}}.trigger called with id=${id}`)
      return true
    })

    return super.init()
  }
}
```

---

## 3 — Real Implementation (Production)

```js
// srv/external/{{EXTERNAL_SERVICE_NAME}}-real.js
const cds = require('@sap/cds/lib')

module.exports = class {{EXTERNAL_SERVICE_NAME}}Real extends cds.RemoteService {
  async init () {

    // Modify outbound requests (auth header, transform)
    this.before('*', req => {
      req.headers = {
        ...req.headers,
        'Authorization': `Bearer ${process.env.EXTERNAL_TOKEN}`
      }
    })

    // Transform responses
    this.after('READ', '{{EXTERNAL_ENTITY}}', items => {
      return items.map(item => ({
        ...item,
        name: item.name?.trim()  // normalize
      }))
    })

    return super.init()
  }
}
```

---

## 4 — package.json Configuration

```json
{
  "cds": {
    "requires": {
      "{{EXTERNAL_SERVICE_NAME}}": {
        "kind": "rest",
        "credentials": {
          "url": "https://api.external.com/v1"
        },
        "[development]": {
          "impl": "./srv/external/{{EXTERNAL_SERVICE_NAME}}-mock.js"
        },
        "[production]": {
          "impl": "./srv/external/{{EXTERNAL_SERVICE_NAME}}-real.js",
          "credentials": {
            "url": "${EXTERNAL_SERVICE_URL}"
          }
        }
      }
    }
  }
}
```

---

## 5 — Usage in a Service

```js
// srv/catalog-service.js — consume the external service
const cds = require('@sap/cds/lib')

module.exports = class CatalogService extends cds.ApplicationService {
  async init () {

    // Connect to external service (local or remote — same API)
    const external = await cds.connect.to('{{EXTERNAL_SERVICE_NAME}}')

    this.on('READ', 'Books', async req => {
      // Read from own DB
      const books = await cds.db.run(req.query)

      // Enrich from external service
      const ids = books.map(b => b.externalID).filter(Boolean)
      if (ids.length) {
        const externalData = await external.read('{{EXTERNAL_ENTITY}}')
          .where({ ID: { in: ids } })

        // merge
        return books.map(book => ({
          ...book,
          externalName: externalData.find(e => e.ID === book.externalID)?.name
        }))
      }

      return books
    })

    // Listen to external service events (if any)
    external.on('StatusChanged', async msg => {
      console.log(`[{{EXTERNAL_SERVICE_NAME}}] Status changed:`, msg.data)
      // update own DB
    })

    return super.init()
  }
}
```

---

## Checklist

- [ ] `srv/external/{{EXTERNAL_SERVICE_NAME}}.cds` → service interface definition
- [ ] `srv/external/{{EXTERNAL_SERVICE_NAME}}-mock.js` → mock (dev)
- [ ] `srv/external/{{EXTERNAL_SERVICE_NAME}}-real.js` → real (prod)
- [ ] `package.json` → `[development]` mock / `[production]` real selection
- [ ] Connect with `cds.connect.to()` in the consumer service
- [ ] Test: end-to-end with mock, test prod connection separately

---

## CAP Remote Service Tips

| Situation | Solution |
|-----------|---------|
| S/4HANA connection | `cds import <metadata.xml>` → auto CDS definition |
| BTP service | `cds add <service>` for Calesi integration |
| REST API | Manual CDS definition + RemoteService proxy |
| Timeout | `credentials.timeout: 5000` (ms) |
| Retry | try/catch in handler + `req.error()` |
| Mock development | `[development].impl` → mock file |
