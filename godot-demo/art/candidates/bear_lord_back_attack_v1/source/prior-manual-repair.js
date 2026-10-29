const sharp = require('/Users/leqiong/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const fs = require('fs/promises');
const dir='/private/tmp/bear-back-20261029-edit';

async function main() {
  const mask = Buffer.from(`<svg width="205" height="225" xmlns="http://www.w3.org/2000/svg"><defs><filter id="b" x="-10%" y="-10%" width="120%" height="120%"><feGaussianBlur stdDeviation="2"/></filter></defs><path d="M 15 60 L 26 38 L 40 20 L 60 20 L 93 39 L 113 55 L 123 64 L 146 82 L 163 101 L 174 121 L 190 148 L 193 167 L 185 185 L 176 205 L 155 214 L 130 211 L 105 203 L 82 188 L 63 166 L 45 147 L 32 126 L 21 105 L 10 85 Z" fill="white" filter="url(#b)"/></svg>`);
  const cut = await sharp(dir+'/source-frame-49.png').extract({left:748,top:520,width:205,height:225}).ensureAlpha().composite([{input:mask,blend:'dest-in'}]).png().toBuffer();
  const rotated = await sharp(cut).rotate(-49,{background:{r:0,g:0,b:0,alpha:0}}).resize({width:Math.round(317*.773)}).png().toBuffer();
  await fs.writeFile(dir+'/weapon-cutout.png',rotated);
  let meta=await sharp(rotated).metadata(); console.log('patch',meta.width,meta.height);
  const x=719,y=281;
  const result=await sharp(dir+'/short-clipped.png').composite([{input:rotated,left:x,top:y}]).png().toBuffer();
  await fs.writeFile(dir+'/manual-first.png',result);
}
main().catch(e=>{console.error(e);process.exit(1)});
