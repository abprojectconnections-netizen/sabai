import { FileBlob, SpreadsheetFile } from '@oai/artifact-tool';

const inputPath = 'D:/Project/Document/e-Travel/Travel_Super_App_STEP8_Complete_Database_Data_Dictionary.xlsx';
const workbook = await SpreadsheetFile.importXlsx(await FileBlob.load(inputPath));
const overview = await workbook.inspect({
  kind: 'workbook,sheet,table',
  maxChars: 12000,
  tableMaxRows: 12,
  tableMaxCols: 14,
  tableMaxCellChars: 120,
});
console.log(overview.ndjson);

for (const sheetName of ['README', 'Data Dictionary', 'Summary', 'Index']) {
  try {
    const preview = await workbook.render({ sheetName, autoCrop: 'all', scale: 1, format: 'png' });
    const bytes = new Uint8Array(await preview.arrayBuffer());
    await (await import('node:fs/promises')).writeFile(`D:/Project/apptravel/tmp_${sheetName.replaceAll(' ', '_')}.png`, bytes);
    console.log(`Rendered ${sheetName}`);
  } catch (_) {
    // Sheet does not exist; the workbook summary above remains authoritative.
  }
}
