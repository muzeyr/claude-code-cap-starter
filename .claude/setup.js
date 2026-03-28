#!/usr/bin/env node
/**
 * Claude Code Setup — for CAP + wdi5 projects
 * Usage: npm run setup:claude
 */

const readline = require('readline');
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const TPL_DIR = path.join(__dirname, 'templates');

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
const ask = (q, def) => new Promise(r => rl.question(
  def ? `${q} [${def}]: ` : `${q}: `,
  ans => r(ans.trim() || def || '')
));

function render(tpl, vars) {
  return tpl.replace(/\{\{(\w+)\}\}/g, (_, k) => vars[k] ?? `{{${k}}}`);
}

function writeIfNotExists(filePath, content) {
  if (fs.existsSync(filePath)) {
    console.log(`  ⚠️  Already exists, skipped: ${path.relative(ROOT, filePath)}`);
    return;
  }
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, content, 'utf8');
  console.log(`  ✓  Created: ${path.relative(ROOT, filePath)}`);
}

function writeAlways(filePath, content) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, content, 'utf8');
  console.log(`  ✓  Written: ${path.relative(ROOT, filePath)}`);
}

function autoDetect() {
  const detected = {};

  // package.json → name, description
  const pkgPath = path.join(ROOT, 'package.json');
  if (fs.existsSync(pkgPath)) {
    const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
    detected.projectName = pkg.name?.replace(/^@[^/]+\//, '') ?? path.basename(ROOT);
    detected.projectDesc = pkg.description ?? 'SAP CAP project';
    // sapux → first app directory
    if (Array.isArray(pkg.sapux) && pkg.sapux.length) {
      detected.appDir = path.basename(pkg.sapux[0]);
    }
  }

  // db/schema.cds → namespace, entity list
  const schemaPath = path.join(ROOT, 'db', 'schema.cds');
  if (fs.existsSync(schemaPath)) {
    const schema = fs.readFileSync(schemaPath, 'utf8');
    const nsMatch = schema.match(/^namespace\s+([\w.]+)/m);
    if (nsMatch) detected.namespace = nsMatch[1];
    const entities = [...schema.matchAll(/^entity\s+(\w+)/gm)].map(m => `- **${m[1]}**`);
    if (entities.length) detected.entityList = entities.join('\n');
  }

  // srv/*.cds → service name, path, file
  const srvDir = path.join(ROOT, 'srv');
  if (fs.existsSync(srvDir)) {
    const cdsFiles = fs.readdirSync(srvDir).filter(f => f.endsWith('.cds'));
    for (const file of cdsFiles) {
      const content = fs.readFileSync(path.join(srvDir, file), 'utf8');
      const svcMatch = content.match(/service\s+(\w+)\s*(?:@\(path\s*:\s*['"]([^'"]+)['"]\))?/);
      if (svcMatch) {
        detected.serviceName = svcMatch[1];
        detected.servicePath = svcMatch[2] ?? svcMatch[1].replace(/Service$/i, '').toLowerCase();
        detected.serviceFile = file;
        break;
      }
    }
  }

  // app/ directory — if sapux not found, use first subdirectory
  if (!detected.appDir) {
    const appDir = path.join(ROOT, 'app');
    if (fs.existsSync(appDir)) {
      const dirs = fs.readdirSync(appDir).filter(f =>
        fs.statSync(path.join(appDir, f)).isDirectory() && !f.startsWith('_')
      );
      if (dirs.length) detected.appDir = dirs[0];
    }
  }

  return detected;
}

async function main() {
  console.log('\n── Claude Code Setup ──\n');

  const d = autoDetect();
  console.log('Detected:');
  Object.entries(d).forEach(([k, v]) => console.log(`  ${k}: ${v}`));
  console.log();

  // Only ask for values that could not be detected
  const namespace   = d.namespace   ?? await ask('CDS namespace (e.g. com.uzi.bookshop)', 'sap.capire.bookshop');
  const projectName = d.projectName ?? await ask('Project name', path.basename(ROOT));
  const projectDesc = d.projectDesc ?? await ask('Short description', 'SAP CAP project');
  const serviceName = d.serviceName ?? await ask('Service name (e.g. AdminService)', 'AdminService');
  const servicePath = d.servicePath ?? await ask('Service URL path (e.g. admin)', 'admin');
  const serviceFile = d.serviceFile ?? await ask('Service file (e.g. admin-service.cds)', 'admin-service.cds');
  const appDir      = d.appDir      ?? await ask('App directory (e.g. admin-books)', 'admin-books');
  const entityList  = d.entityList  ?? '(Add entity list here)';

  // --- Language support ---
  const langInput = await ask('Supported languages (comma-separated, e.g: en,de,tr)', 'en');
  const languages = langInput.split(',').map(l => l.trim().toLowerCase()).filter(Boolean);
  console.log(`  Selected languages: ${languages.join(', ')}`);

  const vars = {
    NAMESPACE:           namespace,
    PROJECT_NAME:        projectName,
    PROJECT_DESCRIPTION: projectDesc,
    PROJECT_DIR:         path.basename(ROOT),
    SERVICE_NAME:        serviceName,
    SERVICE_PATH:        servicePath,
    SERVICE_FILE:        serviceFile,
    SERVICE_HANDLER:     serviceFile.replace(/\.cds$/, '.js'),
    APP_DIR:             appDir,
    ENTITY_LIST:         entityList,
  };

  console.log('\n── Generating files ──\n');

  // 1. CLAUDE.md
  const claudeMdTpl = fs.readFileSync(path.join(TPL_DIR, 'CLAUDE.md.tpl'), 'utf8');
  writeAlways(path.join(ROOT, 'CLAUDE.md'), render(claudeMdTpl, vars));

  // 2. Skills
  const skillsMap = {
    'wdi5-test':  path.join(TPL_DIR, 'skills', 'wdi5-test.tpl'),
    'cds-entity': path.join(TPL_DIR, 'skills', 'cds-entity.tpl'),
    'fiori-page': path.join(TPL_DIR, 'skills', 'fiori-page.tpl'),
    'cds-service':path.join(TPL_DIR, 'skills', 'cds-service.tpl'),
    'cds-auth':   path.join(TPL_DIR, 'skills', 'cds-auth.tpl'),
    'cds-event':  path.join(TPL_DIR, 'skills', 'cds-event.tpl'),
    'cds-remote': path.join(TPL_DIR, 'skills', 'cds-remote.tpl'),
  };
  for (const [name, tplPath] of Object.entries(skillsMap)) {
    if (!fs.existsSync(tplPath)) continue;
    const tpl = fs.readFileSync(tplPath, 'utf8');
    writeAlways(
      path.join(ROOT, '.claude', 'skills', name, 'SKILL.md'),
      render(tpl, vars)
    );
  }

  // 3. settings.json (hooks)
  const settings = {
    hooks: {
      PreToolUse: [{
        matcher: 'Edit|Write',
        hooks: [{
          type: 'command',
          command: `jq -r '.tool_input.file_path' | { read -r f; echo "$f" | grep -qE '(\\.env$|wdi5\\.db$)' && echo '{"decision":"block","reason":"This file is protected."}' || true; } 2>/dev/null || true`,
          statusMessage: 'Checking protected files...'
        }]
      }],
      PostToolUse: [
        {
          matcher: 'Edit|Write',
          hooks: [{
            type: 'command',
            command: `jq -r '.tool_input.file_path // .tool_response.filePath' | { read -r f; echo "$f" | grep -qE '\\.cds$' && cds compile "$f" > /dev/null 2>&1 || { echo "[CDS] Syntax error: $f"; cds compile "$f" 2>&1 | head -5; }; } 2>/dev/null || true`,
            statusMessage: 'Checking CDS syntax...'
          }]
        },
        {
          matcher: 'Edit|Write',
          hooks: [{
            type: 'agent',
            if: 'Edit(**/schema.cds)|Write(**/schema.cds)',
            prompt: `schema.cds was updated. Do two things:

1) Sync CSV seed files:
   Namespace: ${namespace}. Run cds compile index.cds --to json. Read db/data/ files. Compare each CSV header (semicolon separator) against the entity schema. If there is a difference, update only the first (header) row — do not touch data rows. CAP rules: Association->fieldName_ID/code, no managed fields, no to-many, no LargeBinary.

2) Sync i18n files:
   Supported languages: ${languages.join(',')}. Language list is also in .claude/i18n-config.json.
   Scan schema.cds for @title: '{i18n>KEY}' patterns and collect all KEY values.
   For each app (if app/*/webapp/i18n/ directory exists) and each language:
   - Check i18n.properties (default) + i18n_<lang>.properties files.
   - Append missing KEYs at the end of the file. Do not touch existing keys.
   - Use a human-readable form of the KEY as the value (camelCase -> spaced words).
   - Example: ProductName = Product Name`,
            timeout: 120,
            statusMessage: 'Syncing CSV and i18n files...'
          }]
        }
      ]
    }
  };
  writeAlways(
    path.join(ROOT, '.claude', 'settings.json'),
    JSON.stringify(settings, null, 2) + '\n'
  );

  // 4. i18n config file
  const i18nConfig = { languages, defaultLang: languages[0] ?? 'en' };
  writeAlways(
    path.join(ROOT, '.claude', 'i18n-config.json'),
    JSON.stringify(i18nConfig, null, 2) + '\n'
  );

  // 5. Create i18n files (for each app)
  const appRootDir = path.join(ROOT, 'app');
  if (fs.existsSync(appRootDir)) {
    const appDirs = fs.readdirSync(appRootDir).filter(f =>
      fs.statSync(path.join(appRootDir, f)).isDirectory() && !f.startsWith('_')
    );
    for (const app of appDirs) {
      const i18nDir = path.join(appRootDir, app, 'webapp', 'i18n');
      if (!fs.existsSync(i18nDir)) continue;

      // Default i18n.properties
      writeIfNotExists(path.join(i18nDir, 'i18n.properties'), `# ${app} — default i18n\n`);

      // Per language
      for (const lang of languages) {
        writeIfNotExists(
          path.join(i18nDir, `i18n_${lang}.properties`),
          `# ${app} — ${lang}\n`
        );
      }
    }
  }

  // 6. Memory files
  const memDir = path.join(ROOT, '.claude', 'memory');
  writeIfNotExists(path.join(memDir, 'project_context.md'), [
    '---',
    `name: Project Context`,
    `description: Technical structure of the ${projectName} project`,
    'type: project',
    '---',
    '',
    `${projectName} — ${projectDesc}`,
    '',
    `**Namespace:** ${namespace}`,
    `**Service:** ${serviceName} (/${servicePath}/)`,
    `**App:** app/${appDir}/`,
    '',
    '**Why:** CAP + wdi5 learning/development project.',
    '**How to apply:** Follow CDS idioms, Fiori Elements constraints, and wdi5 Page Object Model patterns.',
  ].join('\n'));

  writeIfNotExists(path.join(memDir, 'MEMORY.md'), [
    '# Memory Index',
    '',
    `- [Project Context](project_context.md) — ${projectName}: namespace, service, app structure`,
  ].join('\n'));

  console.log('\n── Setup complete ──');
  console.log('\nNext step: Restart Claude Code or open /hooks.\n');
  rl.close();
}

main().catch(e => { console.error(e); rl.close(); process.exit(1); });
