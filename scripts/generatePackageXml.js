const fs = require('fs');
const path = require('path');

const folder = process.argv[2] || 'force-app/main/default';

const metadataTypes = {
  classes: 'ApexClass',
  lwc: 'LightningComponentBundle',
  aura: 'AuraDefinitionBundle',
  objects: 'CustomObject',
  triggers: 'ApexTrigger',
  layouts: 'Layout',
  permissionsets: 'PermissionSet',
  staticresources: 'StaticResource',
  workflows: 'Workflow',
};

function scanMetadataTypes(basePath) {
  const typesMap = {};

  for (const dir of Object.keys(metadataTypes)) {
    const fullDir = path.join(basePath, dir);
    if (!fs.existsSync(fullDir)) continue;

    const files = fs.readdirSync(fullDir);
    const items = new Set();

    files.forEach(file => {
      const match = file.match(/^(.+?)\.(cls|trigger|js|html|xml|meta\.xml)$/);
      if (match) items.add(match[1]);
    });

    if (items.size > 0) {
      typesMap[metadataTypes[dir]] = [...items];
    }
  }

  return typesMap;
}

function buildPackageXml(metadataMap, version = '59.0') {
  const lines = ['<?xml version="1.0" encoding="UTF-8"?>',
    '<Package xmlns="http://soap.sforce.com/2006/04/metadata">'];

  for (const [type, members] of Object.entries(metadataMap)) {
    lines.push('  <types>');
    members.sort().forEach(m => lines.push(`    <members>${m}</members>`));
    lines.push(`    <name>${type}</name>`);
    lines.push('  </types>');
  }

  lines.push(`  <version>${version}</version>`);
  lines.push('</Package>');

  return lines.join('\n');
}

const metadata = scanMetadataTypes(folder);
const xml = buildPackageXml(metadata);

fs.writeFileSync('package.xml', xml);
console.log('✅ package.xml generated successfully.');
