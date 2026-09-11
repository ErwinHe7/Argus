import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
const root=resolve(fileURLToPath(new URL('../../../',import.meta.url)),'public');
const server=createServer(async(req,res)=>{
  const url=new URL(req.url,'http://127.0.0.1');
  const pathname=['/','/strategy-auth/callback'].includes(url.pathname)?'/app/research-desk/index.html':url.pathname;
  const target=resolve(root,'.'+decodeURIComponent(pathname));
  if(!target.startsWith(root+sep)){res.writeHead(403);res.end();return;}
  try{const data=await readFile(target);const extension=target.split('.').pop();res.writeHead(200,{'Content-Type':({html:'text/html',js:'text/javascript',css:'text/css',json:'application/json',png:'image/png',ttf:'font/ttf',md:'text/markdown'})[extension]??'application/octet-stream','Cache-Control':'no-store'});res.end(data);}catch{res.writeHead(404);res.end('Not found');}
});
const port=Number(process.env.PORT || 3117);
server.listen(port,'127.0.0.1',()=>console.log(`Strategy preview: http://127.0.0.1:${port}/#/strategies`));
