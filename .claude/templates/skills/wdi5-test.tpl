---
name: wdi5-test
description: Generates wdi5 E2E test code for a given page object or scenario.
---

# wdi5-test Skill

Generates wdi5 E2E test code for this project. Uses the Page Object Model pattern.

## Project Structure

```
app/{{APP_DIR}}/webapp/test/wdi5/
├── specs/          → Test scenarios
└── pageobjects/    → Page Objects
```

## wdi5 Code Patterns

### Element selection
```js
const btn = await browser.asControl({
    selector: {
        controlType: "sap.m.Button",
        viewName: "sap.fe.templates.ListReport.ListReport",
        properties: { text: "Create" }
    }
});
```

### Page Object action method
```js
module.exports = {
    async clickCreate() {
        const btn = await browser.asControl({
            selector: { controlType: "sap.m.Button", properties: { text: "Create" } }
        });
        await btn.press();
    }
};
```

### Spec block
```js
describe("{{PROJECT_NAME}}", () => {
    before(async () => {
        await browser.url("/{{SERVICE_PATH}}/webapp/index.html");
    });

    it("should display the list", async () => {
        // assertion
    });
});
```

## Rules

- Add without breaking existing files
- Open URL with `before()`
- Write code in English
