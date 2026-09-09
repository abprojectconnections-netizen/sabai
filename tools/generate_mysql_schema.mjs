import fs from 'node:fs/promises';
import { FileBlob, SpreadsheetFile } from '@oai/artifact-tool';

const inputPath = 'D:/Project/Document/e-Travel/Travel_Super_App_STEP8_Complete_Database_Data_Dictionary.xlsx';
const outputDir = 'D:/Project/apptravel/database/migrations';
const outputPath = `${outputDir}/000001_travel_super_app_schema.up.sql`;
const downOutputPath = `${outputDir}/000001_travel_super_app_schema.down.sql`;

const workbook = await SpreadsheetFile.importXlsx(await FileBlob.load(inputPath));
const dictionary = workbook.worksheets.getItem('Data_Dictionary').getUsedRange().values;
const relationships = workbook.worksheets.getItem('Relationships').getUsedRange().values;

const quote = (identifier) => `\`${String(identifier).replaceAll('`', '``')}\``;
const sqlString = (value) => `'${String(value).replaceAll("'", "''")}'`;
const normalizeType = (dataType) => String(dataType).trim().replace(/^UUID$/i, 'CHAR(36)');

const tables = new Map();
for (const row of dictionary.slice(1)) {
  const [module, table, column, dataType, constraint, description] = row;
  if (!table || !column || !dataType) continue;
  if (!tables.has(table)) tables.set(table, { module, columns: [] });
  tables.get(table).columns.push({ column, dataType: normalizeType(dataType), constraint: String(constraint ?? ''), description: String(description ?? '') });
}

const foreignKeys = relationships.slice(1)
  .filter(([sourceTable, sourceColumn, targetTable, targetColumn]) => sourceTable && sourceColumn && targetTable && targetColumn)
  .map(([sourceTable, sourceColumn, targetTable, targetColumn, relationship]) => ({ sourceTable, sourceColumn, targetTable, targetColumn, relationship }));

const indexedColumns = new Set();
for (const [tableName, table] of tables) {
  for (const column of table.columns) {
    const constraint = column.constraint.toUpperCase();
    if (constraint.includes('PK') || constraint.includes('UQ')) {
      indexedColumns.add(`${tableName}.${column.column}`);
    }
  }
}

function columnSql(column) {
  const key = column.constraint.toUpperCase();
  const parts = [quote(column.column), column.dataType];
  if (key.includes('NOT NULL') || key.includes('PK')) parts.push('NOT NULL');
  if (key.includes('UQ')) parts.push('UNIQUE');
  return `${parts.join(' ')} COMMENT ${sqlString(column.description)}`;
}

function constraintName(prefix, ...parts) {
  return `${prefix}_${parts.join('_')}`.replace(/[^A-Za-z0-9_]/g, '_').slice(0, 60);
}

const lines = [
  '-- Generated from Travel_Super_App_STEP8_Complete_Database_Data_Dictionary.xlsx.',
  '-- Target: MySQL 8.0+, InnoDB, utf8mb4. Apply to an empty Travel Super App database.',
  'SET NAMES utf8mb4;',
  'SET FOREIGN_KEY_CHECKS = 0;',
  '',
];

for (const [tableName, table] of tables) {
  const primaryKey = table.columns.filter((column) => column.constraint.toUpperCase().includes('PK')).map((column) => quote(column.column));
  const definitions = table.columns.map(columnSql);
  if (primaryKey.length) definitions.push(`PRIMARY KEY (${primaryKey.join(', ')})`);
  lines.push(`-- ${table.module}`, `CREATE TABLE IF NOT EXISTS ${quote(tableName)} (`, definitions.map((definition) => `  ${definition}`).join(',\n'), ') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;', '');
}

lines.push('-- Foreign-key indexes and constraints');
const emittedIndexes = new Set();
const emittedNames = new Set();
const assertUniqueName = (name) => {
  if (emittedNames.has(name)) throw new Error(`Generated duplicate database object name: ${name}`);
  emittedNames.add(name);
};
for (const fk of foreignKeys) {
  const indexName = constraintName('idx', fk.sourceTable, fk.sourceColumn);
  const indexKey = `${fk.sourceTable}.${fk.sourceColumn}`;
  if (!emittedIndexes.has(indexKey)) {
    assertUniqueName(indexName);
    lines.push(`CREATE INDEX ${quote(indexName)} ON ${quote(fk.sourceTable)} (${quote(fk.sourceColumn)});`);
    emittedIndexes.add(indexKey);
  }
  const targetIndexKey = `${fk.targetTable}.${fk.targetColumn}`;
  if (!indexedColumns.has(targetIndexKey) && !emittedIndexes.has(targetIndexKey)) {
    const targetIndexName = constraintName('idx', fk.targetTable, fk.targetColumn);
    assertUniqueName(targetIndexName);
    lines.push(`CREATE INDEX ${quote(targetIndexName)} ON ${quote(fk.targetTable)} (${quote(fk.targetColumn)});`);
    emittedIndexes.add(targetIndexKey);
  }
  const fkName = constraintName('fk', fk.sourceTable, fk.sourceColumn, fk.targetTable);
  assertUniqueName(fkName);
  lines.push(`ALTER TABLE ${quote(fk.sourceTable)} ADD CONSTRAINT ${quote(fkName)} FOREIGN KEY (${quote(fk.sourceColumn)}) REFERENCES ${quote(fk.targetTable)} (${quote(fk.targetColumn)}) ON UPDATE CASCADE ON DELETE RESTRICT;`);
}

lines.push('', 'SET FOREIGN_KEY_CHECKS = 1;', '');
await fs.mkdir(outputDir, { recursive: true });
await fs.writeFile(outputPath, lines.join('\n'), 'utf8');

const downLines = [
  '-- Rollback for 000001. This permanently removes all Travel Super App database data.',
  'SET FOREIGN_KEY_CHECKS = 0;',
  '',
  ...[...tables.keys()].reverse().map((tableName) => `DROP TABLE IF EXISTS ${quote(tableName)};`),
  '',
  'SET FOREIGN_KEY_CHECKS = 1;',
  '',
];
await fs.writeFile(downOutputPath, downLines.join('\n'), 'utf8');

const validation = [];
for (const fk of foreignKeys) {
  const source = tables.get(fk.sourceTable)?.columns.find((column) => column.column === fk.sourceColumn);
  const target = tables.get(fk.targetTable)?.columns.find((column) => column.column === fk.targetColumn);
  if (!source || !target) validation.push(`${fk.sourceTable}.${fk.sourceColumn} -> ${fk.targetTable}.${fk.targetColumn}`);
}
console.log(JSON.stringify({ tables: tables.size, foreignKeys: foreignKeys.length, unresolvedRelationships: validation, outputPath, downOutputPath }, null, 2));
