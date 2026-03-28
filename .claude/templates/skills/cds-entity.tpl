---
name: cds-entity
description: Adds a new CDS entity. Creates schema, service projection, annotations, i18n and seed data. Use for "add entity", "add to CDS model", "new table".
---

# cds-entity Skill

Adds a new entity following CAP best practices. Not just the schema — annotations, i18n, and seed data all together.

## Files to Edit (in order)

```
db/schema.cds                      ← 1. Entity definition (fields only, no annotations)
srv/{{SERVICE_FILE}}               ← 2. Projection (add to existing service file)
app/labels.cds                     ← 3. @title annotations (annotate block)
app/*/webapp/i18n/i18n.properties  ← 4. i18n key=value pairs (MANDATORY)
app/{{APP_DIR}}/fiori-service.cds  ← 5. ObjectPage facets + draft
db/data/{{NAMESPACE}}-Entity.csv   ← 6. Seed data (follow namespace format of existing CSVs)
```

> **STRICT RULES:**
> - Entities always go into `db/schema.cds` — never create a new `.cds` file.
> - Only field definitions go in `db/schema.cds` — no `@title` annotations here.
> - `@title: '{i18n>Key}'` annotations go into `app/labels.cds` as an `annotate` block.
> - Immediately after adding a key reference to `app/labels.cds`, add the `Key = Value` pair to all `i18n*.properties` files — this step cannot be skipped.
> - Read `.claude/i18n-config.json` → find out which languages are supported, add to each `i18n_<lang>.properties`.
> - CSV filename: follow the namespace format of existing files in `db/data/`.

---

## 1 — db/schema.cds (append to existing file, do NOT create new file)

Read `db/schema.cds` first — find the namespace and existing entities. Append the entity at the **end** of the file. No `@title` annotations here.

```cds
entity Reviews {
  key ID       : Integer;
  book         : Association to Books;
  rating       : Integer @assert.range: [1, 5];
  comment      : String(500) @UI.MultiLineText;
  reviewer     : String(100);
}
```

**Rules:**
- Do NOT create a new file — always append to `db/schema.cds`
- Do NOT add `managed` or `custom.managed` unless explicitly requested
- Validation → `@assert.range`, `@assert.format`, `@mandatory`
- `@title` annotations do NOT go here — they go in `app/labels.cds`
- Sensitive data → `@PersonalData.FieldSemantics: 'DataSubjectID'` (GDPR)
- Localization → `localized String` (auto-generates `_texts` entity)

---

## 2 — srv/{{SERVICE_FILE}} (Projection)

Read the existing service file, then add the entity projection:

```cds
entity Reviews as projection on my.Reviews;
```

With draft:
```cds
entity Reviews as projection on my.Reviews actions {
  action submit() returns Reviews;
};
```

---

## 3 — app/labels.cds (@title annotations)

Read `app/labels.cds` — add the new namespace to `using` imports if needed. Then add the `annotate` block:

```cds
annotate schema.Reviews with @title: '{i18n>Review}' {
  ID       @UI.Hidden;
  book     @title: '{i18n>Book}'     @Common: { Text: book.title, TextArrangement: #TextOnly };
  rating   @title: '{i18n>Rating}';
  comment  @title: '{i18n>Comment}';
  reviewer @title: '{i18n>Reviewer}';
}
```

**Rules:**
- `@title` annotations ONLY go here — not in `db/schema.cds`
- Do not add a key that already exists (e.g. ID, CreatedAt)
- Do not add a `using` line if the namespace is already imported

---

## 4 — app/*/webapp/i18n/i18n.properties (key=value pairs)

For every `{i18n>KEY}` added to `app/labels.cds`, write the corresponding value in all i18n files.

1. Read `.claude/i18n-config.json` → get the list of supported languages
2. Scan all `webapp/i18n/` folders under `app/`
3. For each folder: add to `i18n.properties` + `i18n_<lang>.properties` per language
4. Do not add a key that already exists

```properties
# i18n.properties (default — usually English)
Review = Review
Reviews = Reviews
Reviewer = Reviewer
Rating = Rating
Comment = Comment

# i18n_de.properties
Review = Bewertung
Reviews = Bewertungen
Reviewer = Bewerter
Rating = Bewertung
Comment = Kommentar
```

**Rule:** This step cannot be skipped after adding `{i18n>KEY}` references to `app/labels.cds`.

---

## 5 — app/{{APP_DIR}}/fiori-service.cds (ListReport + ObjectPage + Draft)

```cds
////////////////////////////////////////////////////////////////////////////
//  Reviews — List + Object Page
////////////////////////////////////////////////////////////////////////////
annotate {{SERVICE_NAME}}.Reviews with @(
  Common.SemanticKey : [ID],
  UI: {
    Identification  : [{ Value: reviewer }],
    SelectionFields : [book_ID, rating],
    LineItem: [
      { Value: book.title,  Label: '{i18n>Book}'     },
      { Value: reviewer,    Label: '{i18n>Reviewer}' },
      { Value: rating,      Label: '{i18n>Rating}'   },
    ],
    HeaderInfo: {
      TypeName       : '{i18n>Review}',
      TypeNamePlural : '{i18n>Reviews}',
      Title          : { Value: reviewer },
      Description    : { Value: rating }
    },
    Facets: [
      { $Type: 'UI.ReferenceFacet', Label: '{i18n>General}', Target: '@UI.FieldGroup#General' },
      { $Type: 'UI.ReferenceFacet', Label: '{i18n>Admin}',   Target: '@UI.FieldGroup#Admin'   }
    ],
    FieldGroup#General: {
      Data: [
        { Value: book_ID },
        { Value: rating },
        { Value: comment },
        { Value: reviewer }
      ]
    },
    FieldGroup#Admin: {
      Data: [
        { Value: createdBy },
        { Value: createdAt },
        { Value: modifiedBy },
        { Value: modifiedAt }
      ]
    }
  }
);

annotate {{SERVICE_NAME}}.Reviews with @odata.draft.enabled;
```

**When to add draft:** Only when users will create/edit records. Not needed for read-only entities.

---

## 6 — db/data/{{NAMESPACE}}-Reviews.csv

```csv
ID;book_ID;rating;comment;reviewer
1;1;5;Great book!;Alice
2;2;4;Very informative;Bob
```

**CAP CSV rules:**
- Separator: semicolon (`;`)
- Association → `fieldName_ID` or `fieldName_code`
- managed fields (createdAt etc.) → check existing CSVs; include only if they do
- LargeBinary → do not include
- Filename: follow naming convention of existing CSVs (e.g. `{{NAMESPACE}}-EntityName.csv`)

---

## Checklist (for every new entity)

- [ ] `db/schema.cds` → entity fields (no new file, no `@title`)
- [ ] `srv/{{SERVICE_FILE}}` → projection (add to existing service)
- [ ] `app/labels.cds` → `annotate` block with `@title: '{i18n>KEY}'` references
- [ ] `app/*/webapp/i18n/i18n.properties` + `i18n_<lang>.properties` → `KEY = Value` pairs (**mandatory**)
- [ ] `app/{{APP_DIR}}/fiori-service.cds` → ListReport + ObjectPage + draft
- [ ] `db/data/{{NAMESPACE}}-Entity.csv` → follow namespace format, add seed data

---

## CAP Best Practices

| Topic | Rule |
|-------|------|
| Entity definition | `db/schema.cds` — fields and validation annotations only |
| i18n / @title | `app/labels.cds` — as annotate blocks |
| UI Facets | `app/<dir>/fiori-service.cds` — ObjectPage layout |
| ID generation | UUID key — CAP generates automatically |
| Validation | `@assert.*` in schema, `req.error()` in handler |
| Auth | `@(requires: 'role')` at service or entity level |
| Draft | Add `@odata.draft.enabled` when users edit records |
| Localization | Use `localized String` for translatable fields |
| GDPR | Personal data → `@PersonalData` annotation |
