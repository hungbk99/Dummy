#!/usr/bin/env python3
"""Extract the QSPI worksheet using only the Python standard library."""
import hashlib,json,sys,xml.etree.ElementTree as ET
from pathlib import Path
from zipfile import ZipFile
p=Path(sys.argv[1] if len(sys.argv)>1 else 'FU3_IP_Testplan (2).xlsx')
ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
with ZipFile(p) as z:
 strings=[''.join(x.itertext()) for x in ET.fromstring(z.read('xl/sharedStrings.xml')).findall('s:si',ns)]
 rels={r.attrib['Id']:r.attrib['Target'] for r in ET.fromstring(z.read('xl/_rels/workbook.xml.rels'))}
 sheet=next(s for s in ET.fromstring(z.read('xl/workbook.xml')).find('s:sheets',ns) if s.attrib['name']=='QSPI')
 target=rels[sheet.attrib['{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id']]
 path=target.lstrip('/') if target.startswith('/') else 'xl/'+target
 rows=[]
 for row in ET.fromstring(z.read(path)).findall('s:sheetData/s:row',ns):
  cells={}
  for c in row:
   v=c.find('s:v',ns)
   if v is None:continue
   value=strings[int(v.text)] if c.attrib.get('t')=='s' else v.text
   cells[''.join(x for x in c.attrib['r'] if x.isalpha())]=value
  if cells.get('C','').startswith('QSPI_'):
   rows.append({'row':int(row.attrib['r']),'id':cells['C'],'category':cells.get('B',''),'description':cells.get('D',''),'bins':cells.get('E',''),'criteria':cells.get('F',''),'flow':cells.get('G',''),'workbook_status':cells.get('I',''),'priority':cells.get('N','')})
result={'workbook':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'sheet':'QSPI','items':rows}
out=Path('regr/qspi_testplan.json');out.write_text(json.dumps(result,indent=2)+'\n')
print('Extracted',len(rows),'items to',out)
