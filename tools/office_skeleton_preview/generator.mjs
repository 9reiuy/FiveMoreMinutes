// Standalone seeded SVG design tool. Never imports or changes the production game.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {furnish,validateGroups} from './functional_groups.mjs';
export const TYPES=['A1','B2','C3','V3'];
const TITLES={A1:'环廊推进',B2:'双中轴渗透',C3:'纵向层进',V3:'分段推进'};
const NAMES={entry:'安全接待',lift:'电梯',main:'主战办公区',west:'西办公厅',east:'东办公厅',hub:'走廊枢纽',ring:'环形走廊',deep:'外办公室',inner:'内嵌经理室',archive:'档案区',storage:'储藏间',server:'机房',meeting:'会议室',training:'培训室',print:'打印区',pantry:'茶水间',lounge:'休息室',finance:'财务室',transition:'横向过渡带',flank:'短侧廊',rear:'后勤侧廊',lower:'入口侧廊',service:'后勤连接'};
const HALLS=new Set(['hub','ring','transition','flank','rear','lower','service','crosshall']);
NAMES.crosshall='设备侧廊';
NAMES.smoking='吸烟室';
const key=(x,y)=>`${x},${y}`,point=c=>c.split(',').map(Number),edge=(a,b)=>a<b?`${a}|${b}`:`${b}|${a}`;
const DIRS=[[1,0],[-1,0],[0,1],[0,-1]];
function rng(seed){let n=seed>>>0;return()=>{n+=0x6D2B79F5;let t=n;t=Math.imul(t^(t>>>15),t|1);t^=t+Math.imul(t^(t>>>7),t|61);return((t^(t>>>14))>>>0)/4294967296;};}
function rect(x,y,w,h){const out=[];for(let j=y;j<y+h;j++)for(let i=x;i<x+w;i++)out.push(key(i,j));return out;}
function box(cells){let x=Infinity,y=Infinity,r=-Infinity,b=-Infinity;for(const c of cells){const[i,j]=point(c);x=Math.min(x,i);y=Math.min(y,j);r=Math.max(r,i);b=Math.max(b,j);}return{x,y,w:r-x+1,h:b-y+1};}

export function topology(type){
 const rooms=[],links=[],routes=[];const r=(id,x,y,w,h)=>rooms.push({id,x,y,w,h});
 const add=pairs=>pairs.forEach(p=>links.push(p));
 if(type==='A1'){
  r('main',2,3,4,3);r('ring',1,2,6,1);r('flank',1,3,1,4);r('rear',6,3,1,4);r('flank',2,6,1,1);r('rear',5,6,1,1);
  r('entry',3,6,2,2);r('lift',3,8,1,1);r('meeting',1,0,2,2);r('print',3,1,2,1);r('pantry',5,0,2,2);
  r('archive',0,3,1,2);r('deep',7,2,2,3);r('finance',7,5,2,2);
  add([['lift','entry'],['entry','main'],['entry','flank'],['entry','rear'],['main','ring'],['main','flank'],['main','rear'],['flank','ring'],['rear','ring'],['meeting','ring'],['meeting','print'],['print','pantry'],['print','ring'],['pantry','ring'],['archive','flank'],['deep','ring'],['deep','rear'],['finance','rear'],['finance','deep']]);
  routes.push(['entry','main','ring','deep','inner'],['entry','flank','ring','meeting','print','pantry','ring','main'],['entry','rear','finance','deep']);
 }else if(type==='B2'){
  r('west',1,2,3,3);r('east',5,2,3,3);r('hub',4,2,1,1);r('entry',0,5,2,1);r('lift',0,6,1,1);r('flank',0,2,1,3);
  r('pantry',0,0,2,2);r('meeting',2,0,1,2);r('training',3,0,1,2);r('archive',5,0,1,2);r('finance',6,0,2,2);
  r('deep',8,0,2,3);r('rear',8,3,1,3);r('server',9,3,1,2);r('storage',9,5,1,1);r('lounge',6,5,2,1);
  add([['lift','entry'],['entry','west'],['entry','flank'],['flank','west'],['flank','pantry'],['pantry','meeting'],['meeting','training'],['training','west'],['west','hub'],['hub','east'],['east','archive'],['east','finance'],['east','deep'],['east','lounge'],['lounge','rear'],['rear','deep'],['rear','server'],['server','deep'],['rear','storage']]);
  routes.push(['entry','west','hub','east','deep','inner'],['entry','flank','pantry','meeting','training','west'],['east','lounge','rear','server','deep']);
 }else if(type==='C3'){
  r('main',2,4,5,3);r('entry',3,7,3,1);r('lift',4,8,1,1);r('transition',2,3,6,1);r('deep',5,0,3,3);
  r('flank',1,2,1,6);r('lower',2,7,1,1);r('archive',0,4,1,2);r('print',0,6,1,2);r('server',0,0,2,2);r('meeting',2,1,2,2);
  r('lounge',7,4,1,3);r('rear',8,0,1,8);r('service',6,7,2,1);
  add([['lift','entry'],['entry','main'],['entry','lower'],['lower','flank'],['flank','main'],['flank','archive'],['flank','print'],['flank','server'],['server','meeting'],['meeting','transition'],['main','transition'],['transition','deep'],['entry','service'],['service','rear'],['rear','deep'],['rear','lounge'],['lounge','main']]);
  routes.push(['entry','main','transition','deep','inner'],['entry','lower','flank','server','meeting','transition'],['entry','service','rear','deep']);
 }else{
  r('main',2,3,4,3);r('entry',3,6,2,1);r('lift',3,7,1,1);r('flank',1,2,1,5);r('lower',2,6,1,1);
  r('print',0,2,1,1);r('archive',0,3,1,2);r('pantry',0,5,1,1);r('meeting',2,1,2,2);r('hub',4,1,3,2);r('deep',7,0,2,3);
  r('lounge',6,4,1,2);r('server',7,4,2,2);r('rear',9,2,1,5);r('crosshall',6,3,3,1);r('service',5,6,4,1);
  add([['lift','entry'],['entry','main'],['entry','lower'],['lower','flank'],['flank','print'],['flank','archive'],['flank','pantry'],['flank','meeting'],['meeting','hub'],['main','hub'],['hub','deep'],['entry','service'],['service','rear'],['rear','deep'],['service','lounge'],['service','server'],['main','lounge'],['lounge','server'],['crosshall','rear'],['crosshall','server']]);
  routes.push(['entry','main','hub','deep','inner'],['entry','lower','flank','meeting','hub'],['entry','service','rear','deep']);
 }
 return{rooms,links,routes};
}
function bfs(start,end,allowed,cross){
 const queue=[start],prev=new Map([[start,null]]);
 for(let i=0;i<queue.length;i++){const c=queue[i];if(c===end)break;const[x,y]=point(c);for(const[dx,dy]of DIRS){const n=key(x+dx,y+dy);if(allowed.has(n)&&!prev.has(n)&&cross(c,n)){prev.set(n,c);queue.push(n);}}}
 if(!prev.has(end))throw Error(`clearance route missing ${start}->${end}`);
 const out=[];for(let c=end;c!==null;c=prev.get(c))out.push(c);return out.reverse();
}
function make(type,seed,attempt){
 const rand=rng((seed^Math.imul(attempt+1,0x9E3779B9))>>>0),int=(a,b)=>a+Math.floor(rand()*(b-a+1));
 const t=topology(type),xs=[0],ys=[0],widths=Array.from({length:11},()=>int(9,12)),heights=Array.from({length:11},()=>int(9,12));
 // Lock the actual shared bands, preserving every frontage rather than shrinking a drawing.
 if(type==='A1'){widths[3]=7;widths[4]=7;heights[6]=5;heights[7]=5;}
 if(type==='B2'){widths[0]=7;widths[1]=7;heights[5]=10;}
 if(type==='C3'){widths[3]=4;widths[4]=5;widths[5]=5;heights[7]=10;}
 if(type==='V3'){widths[3]=7;widths[4]=7;heights[6]=10;}
 const side=int(3,4),major=int(4,5),junction=int(6,8);
 if(type==='A1'){widths[1]=side;widths[6]=side;heights[2]=major;}
 if(type==='B2'){widths[0]=side;widths[1]=14-side;widths[4]=junction;heights[2]=junction;widths[8]=side;}
 if(type==='C3'){widths[1]=side;widths[8]=side;heights[3]=major;}
 if(type==='V3'){widths[1]=side;widths[9]=side;}
 for(let i=0;i<11;i++){xs.push(xs.at(-1)+widths[i]);ys.push(ys.at(-1)+heights[i]);}
 const owners=new Map(),rooms=new Map();
 const entrySpec=t.rooms.find(s=>s.id==='entry'),entryX=xs[entrySpec.x],entryY=ys[entrySpec.y];
 const corridorSegments=[];
 for(const s of t.rooms){
  if(!rooms.has(s.id))rooms.set(s.id,{id:s.id,cells:new Set()});
  let x=xs[s.x],y=ys[s.y],w=xs[s.x+s.w]-x,h=ys[s.y+s.h]-y,segment=null,pocket=null;
  if(s.id==='lift'){x=entryX+4;y=entryY+10;w=6;h=6;}
  else if(HALLS.has(s.id)){
   if(s.id==='hub'&&type==='B2')segment={class:'junction',width:junction};
   else if(s.id==='hub'&&type==='V3'){
    y=ys[s.y+s.h]-major;h=major;segment={class:'main',width:major};
    pocket={room:s.id,x:xs[5],y:ys[s.y+s.h]-junction,w:junction,h:junction,class:'junction',width:junction};
   }else if(s.h===1){const d=['ring','transition'].includes(s.id)?major:side;y=s.id==='crosshall'?y+h-d:y;h=d;segment={class:d===major&&['ring','transition'].includes(s.id)?'main':'side',width:d};}
   else {w=side;segment={class:'side',width:side};}
  }
  const pieces=[{x,y,w,h},...(pocket?[pocket]:[])];
  if(segment)corridorSegments.push({room:s.id,x,y,w,h,...segment});if(pocket)corridorSegments.push(pocket);
  for(const p of pieces)for(const c of rect(p.x,p.y,p.w,p.h)){if(owners.has(c)&&owners.get(c)!==s.id)throw Error('room overlap');owners.set(c,s.id);rooms.get(s.id).cells.add(c);}
 }
 const nest=(parent,id)=>{const p=rooms.get(parent),b=box(p.cells),w=Math.max(id==='inner'?10:7,Math.floor(b.w*.48)),h=Math.max(id==='inner'?11:8,Math.floor(b.h*.44)),left=rand()<.5,x=(type==='A1'&&parent==='deep')?b.x+b.w-w:left?b.x:b.x+b.w-w;
  const cells=new Set(rect(x,b.y,w,h));for(const c of cells){if(!p.cells.has(c))throw Error('invalid nesting');p.cells.delete(c);owners.set(c,id);}rooms.set(id,{id,cells,parent});t.links.push([parent,id]);};
 nest('deep','inner');if(!rooms.has('storage'))nest('archive','storage');
 // Seed decides presence independently of retries: do not drop the optional room to rescue a bad candidate.
 const smokingRequested=rng(seed^0x534D4F4B)()<.45;
 if(smokingRequested){
  let added=false;
  for(const hallId of ['rear','flank']){
   const hall=rooms.get(hallId);if(!hall)continue;const candidates=[...hall.cells].map(point).sort((a,b)=>a[1]-b[1]||a[0]-b[0]);
   for(const [cx,cy]of candidates){for(const direction of [1,-1]){
    if(owners.has(key(cx+direction,cy)))continue;
    const x=direction===1?cx+1:cx-10,y=cy,cells=rect(x,y,10,10);
    if(cells.some(c=>owners.has(c)))continue;
    if(!Array.from({length:10},(_,i)=>key(cx,cy+i)).every(c=>hall.cells.has(c)))continue;
    rooms.set('smoking',{id:'smoking',cells:new Set(cells),branchFrom:hallId});cells.forEach(c=>owners.set(c,'smoking'));t.links.push([hallId,'smoking']);added=true;break;
   }if(added)break;}if(added)break;
  }
  if(!added)throw Error('cannot attach requested smoking branch');
 }
 const swap=rand()<.5;for(const room of rooms.values()){room.kind=room.id;if(swap&&room.id==='print')room.kind='pantry';if(swap&&room.id==='pantry')room.kind='print';if(swap&&room.id==='finance')room.kind='training';room.label=NAMES[room.kind];room.bounds=box(room.cells);}
 const openings=new Set(),doors=[];
 function runsBetween(a,b){const all=[];for(const c of rooms.get(a).cells){const[x,y]=point(c);for(const[dx,dy]of DIRS){const d=key(x+dx,y+dy);if(owners.get(d)===b)all.push({a:c,b:d,v:dx!==0,line:dx?Math.max(x,x+dx):Math.max(y,y+dy),pos:dx?y:x});}}
  all.sort((a,b)=>Number(a.v)-Number(b.v)||a.line-b.line||a.pos-b.pos);const runs=[];for(const s of all){const last=runs.at(-1);if(last&&last[0].v===s.v&&last[0].line===s.line&&last.at(-1).pos+1===s.pos)last.push(s);else runs.push([s]);}return runs;}
 for(const[a,b]of t.links){const runs=runsBetween(a,b).filter(r=>r.length>=3).sort((a,b)=>b.length-a.length);if(!runs.length)throw Error(`no wall ${a}-${b}`);const run=runs[0],width=HALLS.has(a)&&HALLS.has(b)?run.length:Math.min(run.length,['main','west','east'].includes(a)&&HALLS.has(b)?5:3),margin=run.length>=width+2?1:0;let start=int(margin,run.length-width-margin);
  if(a==='entry'||b==='entry'){const desired=run[0].v?entryY+1:entryX+6;start=Math.max(margin,Math.min(run.length-width-margin,desired-run[0].pos));}
  const seg=run.slice(start,start+width);seg.forEach(s=>openings.add(edge(s.a,s.b)));doors.push({a,b,vertical:seg[0].v,line:seg[0].line,start:seg[0].pos,width,glass:false,cells:seg.flatMap(s=>[s.a,s.b])});}
 const glassPair=type==='B2'?['meeting','west']:type==='V3'?['meeting','main']:type==='A1'?['main','ring']:['meeting','transition'];
 let addedGlass=false;for(const run of runsBetween(...glassPair)){for(let offset=1;offset<=run.length-4;offset++){const seg=run.slice(offset,offset+3);if(seg.every(s=>!doors.some(d=>d.cells.includes(s.a)||d.cells.includes(s.b)))){doors.push({a:glassPair[0],b:glassPair[1],vertical:seg[0].v,line:seg[0].line,start:seg[0].pos,width:3,glass:true,cells:seg.flatMap(s=>[s.a,s.b])});addedGlass=true;break;}}if(addedGlass)break;}
 if(!addedGlass)throw Error('no legal observation glass');
 // Combat office frontages: wide existing portals stay open; remaining long
 // spans become continuous glass, with one solid cell at each corner.
 for(const office of ['main','west','east'])if(rooms.has(office))for(const hall of HALLS)if(rooms.has(hall)){
  for(const d of doors)if(!d.glass&&((d.a===office&&d.b===hall)||(d.b===office&&d.a===hall)))d.open=true;
  for(const run of runsBetween(office,hall)){
   let pending=[];
   const flush=()=>{if(pending.length>=2){const s=pending[0];doors.push({a:office,b:hall,vertical:s.v,line:s.line,start:s.pos,width:pending.length,glass:true,officeFrontage:true,cells:pending.flatMap(p=>[p.a,p.b])});}pending=[];};
   for(const s of run.slice(1,-1)){if(doors.some(d=>d.cells.includes(s.a)&&d.cells.includes(s.b))){flush();}else pending.push(s);}flush();
  }
 }
 if(smokingRequested){const run=runsBetween('smoking',undefined).filter(r=>r.length>=6).sort((a,b)=>b.length-a.length)[0];if(!run)throw Error('smoking room has no exterior window');const seg=run.slice(1,5);doors.push({a:'smoking',b:'outside',vertical:seg[0].v,line:seg[0].line,start:seg[0].pos,width:4,glass:true,exterior:true,cells:seg.flatMap(s=>[s.a,s.b])});}
 const furnishing=furnish(rooms,doors,rand,HALLS),furniture=furnishing.items,occupied=furnishing.occupied;
 const cross=(a,b)=>owners.has(a)&&owners.has(b)&&(owners.get(a)===owners.get(b)||openings.has(edge(a,b)));
 const clear=new Set();for(const c of owners.keys()){const[x,y]=point(c);let ok=true;for(let dy=-1;dy<=1&&ok;dy++)for(let dx=-1;dx<=1&&ok;dx++){const q=key(x+dx,y+dy);if(!owners.has(q)||occupied.has(q)||(dx<1&&!cross(q,key(x+dx+1,y+dy)))||(dy<1&&!cross(q,key(x+dx,y+dy+1))))ok=false;}if(ok)clear.add(c);}
 const anchors={};for(const r of rooms.values()){const b=r.bounds,candidates=[...r.cells].filter(c=>clear.has(c));const distance=c=>{const[x,y]=point(c);return Math.abs(x-b.x-b.w/2)+Math.abs(y-b.y-b.h/2);};candidates.sort((a,b)=>distance(a)-distance(b));if(!candidates.length)throw Error(`no center ${r.id}`);anchors[r.id]=candidates[0];}
 const reserve=new Set(),protect=c=>{const[x,y]=point(c);rect(x-1,y-1,3,3).forEach(c=>reserve.add(c));};
 const localPath=(a,b)=>bfs(anchors[a],anchors[b],new Set([...clear].filter(c=>owners.get(c)===a||owners.get(c)===b)),cross);
 for(const[a,b]of t.links)localPath(a,b).forEach(protect);
 for(const d of doors.filter(d=>!d.glass))for(const c of d.cells){const[x,y]=point(c);for(let off=-2;off<=2;off++){const q=d.vertical?key(x+off,y):key(x,y+off);if(owners.has(q))reserve.add(q);}}
 const routes=t.routes.map(ids=>({rooms:ids,points:ids.slice(1).flatMap((id,i)=>localPath(ids[i],id))}));
 const decor=[];
 for(const room of rooms.values())if(HALLS.has(room.id)||room.id==='smoking'){
  const wallCandidates=[];for(const c of room.cells){const[x,y]=point(c);for(const[dx,dy]of DIRS){const n=key(x+dx,y+dy);if(owners.get(n)===room.id||openings.has(edge(c,n)))continue;if(doors.some(d=>d.cells.some(q=>{const[p,t]=point(q);return Math.abs(p-x)+Math.abs(t-y)<=2;})))continue;wallCandidates.push({x:dx?x+(dx===1?1:0):x+.5,y:dy?y+(dy===1?1:0):y+.5,dx,dy,inside:c,outside:n});}}
  const limit=Math.min(6,Math.max(2,Math.ceil(room.cells.size/60))),selected=[];
  for(const candidate of wallCandidates){if(selected.some(p=>Math.abs(p.x-candidate.x)+Math.abs(p.y-candidate.y)<7))continue;selected.push(candidate);if(selected.length>=limit)break;}
  selected.forEach((p,i)=>decor.push({...p,room:room.id,kind:room.id==='smoking'?(i===0?'通风设施':'吸烟标识'):['告示牌','消防箱','管线','门牌'][i%4],wallMounted:true,collision:false}));
 }
 const enemies=[];for(const r of rooms.values()){if(HALLS.has(r.id)||['entry','lift','storage','smoking'].includes(r.id))continue;const candidates=[...r.cells].filter(c=>clear.has(c)&&!occupied.has(c));for(let i=0;i<(['main','west','east'].includes(r.id)?3:1);i++){if(!candidates.length)break;enemies.push({room:r.id,cell:candidates.splice(int(0,candidates.length-1),1)[0]});}}
 const mirror=rand()<.5,extent=box(owners.keys()),W=extent.x*2+extent.w,transform=c=>{const[x,y]=point(c);return key(mirror?W-1-x:x,y);};
 const data={version:3,type,title:TITLES[type],seed,attempt:attempt+1,mirror,receptionSize:{w:14,h:10},smokingRequested,corridorSegments:corridorSegments.map(s=>({...s,x:mirror?W-s.x-s.w:s.x})),decor:decor.map(d=>({...d,x:mirror?W-d.x:d.x,dx:mirror?-d.dx:d.dx,inside:transform(d.inside),outside:transform(d.outside)})),rooms:[...rooms.values()].map(r=>({...r,cells:[...r.cells].map(transform)})),doors:doors.map(d=>({...d,cells:d.cells.map(transform),line:d.vertical&&mirror?W-d.line:d.line,start:!d.vertical&&mirror?W-d.start-d.width:d.start})),furniture:furniture.map(f=>({...f,x:mirror?W-f.x-f.w:f.x,facing:f.facing&&[mirror?-f.facing[0]:f.facing[0],f.facing[1]],target:f.target&&{x:mirror?W-f.target.x:f.target.x,y:f.target.y}})),groups:furnishing.groups.map(g=>({...g,x:mirror?W-g.x-g.w:g.x,mirror})),enemies:enemies.map(e=>({...e,cell:transform(e.cell)})),routes:routes.map(r=>({...r,points:r.points.map(transform)})),anchors:Object.fromEntries(Object.entries(anchors).map(([id,c])=>[id,transform(c)])),reserved:[...reserve].map(transform),floor:[...owners.keys()].map(transform)};
 data.rooms.forEach(r=>r.bounds=box(r.cells));data.bounds=box(data.floor);data.checks=validate(data);if(!data.checks.ok)throw Error(data.checks.errors.join(';'));return data;
}
export function validate(data){
 const errors=validateGroups(data),owners=new Map();for(const r of data.rooms)for(const c of r.cells){if(owners.has(c))errors.push('room overlap');owners.set(c,r.id);}
 const open=new Set();for(const d of data.doors.filter(d=>!d.glass)){if(d.width<3)errors.push('narrow doorway');for(const a of d.cells)for(const b of d.cells){const p=point(a),q=point(b);if(Math.abs(p[0]-q[0])+Math.abs(p[1]-q[1])===1&&owners.get(a)!==owners.get(b))open.add(edge(a,b));}}
 const occupied=new Set();for(const f of data.furniture)for(const c of rect(f.x,f.y,f.w,f.h)){if(owners.get(c)!==f.room)errors.push('furniture outside room');if(occupied.has(c))errors.push('furniture overlap');occupied.add(c);}for(const c of data.reserved)if(occupied.has(c))errors.push('reserved route blocked');
 const corridorFloor=new Map();
 for(const s of data.corridorSegments||[]){const limits=s.class==='junction'?[6,8]:s.class==='main'?[4,5]:[3,4];if(s.width<limits[0]||s.width>limits[1]||Math.min(s.w,s.h)!==s.width)errors.push('corridor width out of contract');if(!corridorFloor.has(s.room))corridorFloor.set(s.room,new Set());for(const c of rect(s.x,s.y,s.w,s.h)){if(owners.get(c)!==s.room)errors.push('corridor segment outside floor');corridorFloor.get(s.room).add(c);}}
 for(const room of data.rooms.filter(r=>HALLS.has(r.id)))if(!corridorFloor.has(room.id)||room.cells.some(c=>!corridorFloor.get(room.id).has(c)))errors.push('unbounded corridor area');
 const smoking=data.rooms.filter(r=>r.id==='smoking');if(smoking.length>1||Boolean(smoking.length)!==data.smokingRequested)errors.push('smoking branch count mismatch');
 if(smoking.length){const entrances=data.doors.filter(d=>!d.glass&&(d.a==='smoking'||d.b==='smoking'));if(entrances.length!==1||![entrances[0].a,entrances[0].b].some(id=>['flank','rear'].includes(id)))errors.push('smoking room is not a side branch');if(data.routes.some(r=>r.rooms.includes('smoking')))errors.push('smoking room became required route');if(!data.doors.some(d=>d.a==='smoking'&&d.exterior&&d.glass))errors.push('smoking exterior window missing');}
 for(const d of data.decor||[]){const[x,y]=point(d.inside),[u,v]=point(d.outside);if(!d.wallMounted||d.collision!==false||owners.get(d.inside)!==d.room||owners.get(d.outside)===d.room||open.has(edge(d.inside,d.outside))||Math.abs(x-u)+Math.abs(y-v)!==1||d.dx!==u-x||d.dy!==v-y)errors.push('invalid wall decoration');if(data.doors.some(door=>door.cells.some(c=>{const[a,b]=point(c);return Math.abs(a-x)+Math.abs(b-y)<=2;})))errors.push('decoration overlaps door/window');}
 const cross=(a,b)=>owners.has(b)&&(owners.get(a)===owners.get(b)||open.has(edge(a,b)));
 const seen=new Set([data.anchors.entry]),queue=[data.anchors.entry];for(let i=0;i<queue.length;i++){const[x,y]=point(queue[i]);for(const[dx,dy]of DIRS){const n=key(x+dx,y+dy);if(!occupied.has(n)&&!seen.has(n)&&cross(queue[i],n)){seen.add(n);queue.push(n);}}}
 for(const[id,c]of Object.entries(data.anchors))if(!seen.has(c))errors.push(`room unreachable:${id}`);for(const e of data.enemies)if(!seen.has(e.cell)||['entry','lift'].includes(e.room))errors.push('enemy unsafe/unreachable');
 for(const r of data.rooms.filter(r=>r.parent)){const ds=data.doors.filter(d=>!d.glass&&(d.a===r.id||d.b===r.id));if(ds.length!==1||![ds[0].a,ds[0].b].includes(r.parent))errors.push('nested room bypass');}
 for(const route of data.routes)for(let i=0;i<route.points.length;i++){const c=route.points[i],[x,y]=point(c);for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){const q=key(x+dx,y+dy);if(!owners.has(q)||occupied.has(q))errors.push('route footprint blocked');if((dx<1&&!cross(q,key(x+dx+1,y+dy)))||(dy<1&&!cross(q,key(x+dx,y+dy+1))))errors.push('route clearance crosses wall');}if(i&&route.points[i-1]!==c&&!cross(route.points[i-1],c))errors.push('route crosses wall');}
 for(const d of data.doors.filter(d=>!d.glass))for(const c of d.cells){const[x,y]=point(c);for(let off=-2;off<=2;off++)if(occupied.has(d.vertical?key(x+off,y):key(x,y+off)))errors.push('door buffer blocked');}
 return{ok:!errors.length,errors:[...new Set(errors)],floorCells:owners.size,rooms:data.rooms.length,furniture:data.furniture.length,groups:data.groups.length,enemies:data.enemies.length,reception:'14x10',corridorWidths:[...new Set(data.corridorSegments.map(s=>`${s.class}:${s.width}`))],wallDecor:data.decor.length,smoking:smoking.length,doorClearance:2,routeWidth:3};
}
export function generate(type,seed){if(!TYPES.includes(type))throw Error('unknown skeleton');if(!Number.isInteger(seed)||seed<0||seed>0xffffffff)throw Error('seed must be uint32');const reasons=[];for(let i=0;i<100;i++)try{return make(type,seed,i);}catch(e){reasons.push(e.message);}throw Error(`${type}/${seed}: ${[...new Set(reasons)].join('; ')}`);}
const escape=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;');
export function svg(data){
 const S=10,b=data.bounds,pad=40,top=80,w=b.w*S+pad*2,h=b.h*S+top+100,X=x=>pad+(x-b.x)*S,Y=y=>top+(y-b.y)*S;
 const owners=new Map(data.rooms.flatMap(r=>r.cells.map(c=>[c,r.id]))),open=new Set(),glass=new Set();
 for(const d of data.doors)for(const a of d.cells)for(const c of d.cells){const p=point(a),q=point(c);if(Math.abs(p[0]-q[0])+Math.abs(p[1]-q[1])===1&&owners.get(a)!==owners.get(c))(d.glass?glass:open).add(edge(a,c));}
 const out=[`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><title>${data.type} ${escape(data.title)} seed ${data.seed}</title><desc>独立随机白盒，不是运行时画面；布局检查不能替代游戏验收。</desc><style>text{font-family:'Microsoft YaHei',sans-serif;fill:#25333e}.label{font-size:12px;paint-order:stroke;stroke:white;stroke-width:3px}.wall{stroke:#202a32;stroke-width:3.5;stroke-linecap:square}</style><rect width="100%" height="100%" fill="white"/><text x="${w/2}" y="30" text-anchor="middle" font-size="23">${data.type} · ${escape(data.title)} · 种子 ${data.seed}</text><text x="${w/2}" y="53" text-anchor="middle" font-size="12">自由轮廓 / 单层平面 / 三格路线 / 门内两格家具净空 / 未接入游戏</text>`];
 for(const r of data.rooms){const color=r.parent?'#fff0d2':HALLS.has(r.id)?'#e5eaed':r.id==='entry'?'#dfefea':r.id==='smoking'?'#edf0df':'#f1f3f4';for(const c of r.cells){const[x,y]=point(c);out.push(`<rect x="${X(x)}" y="${Y(y)}" width="${S}" height="${S}" fill="${color}"/>`);}}
 const segs=[];for(const[c,id]of owners){const[x,y]=point(c);for(const[dx,dy]of DIRS){const n=key(x+dx,y+dy);if(owners.get(n)===id||open.has(edge(c,n)))continue;if(owners.has(n)&&c>n)continue;segs.push({v:dx!==0,line:dx?(dx===1?x+1:x):(dy===1?y+1:y),pos:dx?y:x,g:glass.has(edge(c,n))});}}
 segs.sort((a,b)=>Number(a.g)-Number(b.g)||Number(a.v)-Number(b.v)||a.line-b.line||a.pos-b.pos);const runs=[];for(const s of segs){const r=runs.at(-1);if(r&&r.g===s.g&&r.v===s.v&&r.line===s.line&&r.end===s.pos)r.end++;else runs.push({...s,end:s.pos+1});}
 for(const r of runs)out.push(`<path ${r.g?'stroke="#1eb4c1" stroke-width="4"':'class="wall"'} d="M${X(r.v?r.line:r.pos)} ${Y(r.v?r.pos:r.line)}L${X(r.v?r.line:r.end)} ${Y(r.v?r.end:r.line)}"/>`);
 for(const d of data.decor){const x=X(d.x-d.dx*.2),y=Y(d.y-d.dy*.2),fire=d.kind==='消防箱',pipe=d.kind==='管线';if(pipe)out.push(`<path d="M${x-d.dy*4} ${y+d.dx*4}L${x+d.dy*4} ${y-d.dx*4}" stroke="#8e969a" stroke-width="2"><title>${escape(d.kind)} · 壁挂无碰撞</title></path>`);else out.push(`<rect x="${x-2}" y="${y-2}" width="4" height="4" fill="${fire?'#c87964':d.kind==='通风设施'?'#87969b':'#7d9cb2'}"><title>${escape(d.kind)} · 壁挂无碰撞</title></rect>`);}
 for(const g of data.groups.filter(g=>g.template!=='shelf'))out.push(`<rect x="${X(g.x)-1}" y="${Y(g.y)-1}" width="${g.w*S+2}" height="${g.h*S+2}" rx="2" fill="none" stroke="#aab6ab" stroke-width=".8" stroke-dasharray="3 3"><title>${escape(g.template)} 功能组</title></rect>`);
 for(const f of data.furniture){const seating=f.kind.includes('椅')||f.kind.includes('沙发');out.push(`<rect x="${X(f.x)}" y="${Y(f.y)}" width="${f.w*S}" height="${f.h*S}" rx="${seating?2:0}" fill="${f.high?'#53616c':seating?'#9eafbb':'#c6cdd2'}" stroke="${f.high?'#33414a':'#8797a2'}"><title>${escape(f.kind)} · ${escape(f.group)}</title></rect>`);
  if(f.facing){const cx=X(f.x+f.w/2),cy=Y(f.y+f.h/2),dx=f.facing[0],dy=f.facing[1],length=seating?4:Math.min(f.w,f.h)*S*.3;out.push(`<path d="M${cx-dx*length/2} ${cy-dy*length/2}L${cx+dx*length} ${cy+dy*length}l${-dx*2-dy*2} ${-dy*2+dx*2}M${cx+dx*length} ${cy+dy*length}l${-dx*2+dy*2} ${-dy*2-dx*2}" stroke="${f.high?'#dce5e8':'#344b5c'}" stroke-width="1" fill="none"/>`);}
 }
 data.routes.forEach((r,i)=>out.push(`<polyline points="${r.points.map(c=>{const[x,y]=point(c);return`${X(x+.5)},${Y(y+.5)}`;}).join(' ')}" stroke="${['#277ccd','#df891e','#9365b2'][i]}" opacity=".8" fill="none" stroke-width="2.4" stroke-dasharray="7 5"/>`));
 for(const e of data.enemies){const[x,y]=point(e.cell);out.push(`<circle cx="${X(x+.5)}" cy="${Y(y+.5)}" r="4" fill="#ce4848" stroke="white"/>`);}
 for(const r of data.rooms){const[x,y]=point(data.anchors[r.id]),segments=data.corridorSegments.filter(s=>s.room===r.id),widthText=segments.length?' '+[...new Set(segments.map(s=>s.width))].join('/')+'格':'';const s=segments.sort((a,b)=>b.w*b.h-a.w*a.h)[0],cx=s?X(s.x+s.w/2):X(x+.5),cy=s?Y(s.y+s.h/2):Y(y+.5)-5,vertical=s&&s.h>s.w;out.push(`<text class="label" x="${cx}" y="${cy}" ${vertical?`transform="rotate(-90 ${cx} ${cy})"`:''} text-anchor="middle" style="font-size:${s||r.bounds.w<12?9:12}px">${escape(r.label)}${r.id==='entry'?' 14×10':widthText}</text>`);}
 out.push(`<text x="${pad}" y="${h-65}" font-size="11">蓝：主推进　橙：短侧翼　紫：后勤侧翼　青：玻璃　虚框：家具组　墙边色块：壁挂布景</text><text x="${pad}" y="${h-43}" font-size="11">接待 14×10；侧廊 3–4 / 主廊 4–5 / 局部枢纽 6–8 格；壁挂 ${data.checks.wallDecor}；吸烟室 ${data.checks.smoking}</text><text x="${pad}" y="${h-21}" font-size="11">独立白盒，未映射正式资产。玻璃完整时按实墙检查；无楼梯或新增安检玩法；无占道落地布景。</text></svg>`);return out.join('\n');
}
export function batch(out,count=10,start=1001){
 fs.mkdirSync(out,{recursive:true});const records=[];for(const type of TYPES)for(let i=0;i<count;i++){const d=generate(type,start+i),name=`${type}-${d.seed}`;fs.writeFileSync(path.join(out,name+'.svg'),svg(d));fs.writeFileSync(path.join(out,name+'.json'),JSON.stringify(d,null,2));records.push({type,seed:d.seed,name,checks:d.checks,attempt:d.attempt});}
 const sections=TYPES.map(type=>`<h2>${type} ${TITLES[type]}</h2><section>${records.filter(r=>r.type===type).map(r=>`<a href="${r.name}.svg"><img loading="lazy" src="${r.name}.svg" alt="${r.name}"><span>${r.name} · ${r.checks.smoking?'有吸烟室':'无吸烟室'} · ${r.checks.wallDecor} 件壁挂布景 · 接待 14×10</span></a>`).join('')}</section>`).join('');
 fs.writeFileSync(path.join(out,'index.html'),`<!doctype html><html lang="zh"><meta charset="utf-8"><title>四骨架随机白盒 V3 · 紧凑走廊与吸烟室</title><style>body{font-family:'Microsoft YaHei',sans-serif;margin:30px;background:#f1f3f5;color:#26313b}section{display:grid;grid-template-columns:repeat(auto-fit,minmax(350px,1fr));gap:16px}a{background:white;padding:12px;text-decoration:none;color:inherit;border:1px solid #d6dce1}img{width:100%;height:330px;object-fit:contain}span{display:block}</style><h1>四骨架随机白盒 V3 · 紧凑走廊与吸烟室</h1><p>普通侧廊 3–4 格，主廊 4–5 格，局部交火枢纽 6–8 格。接待室仍为 14×10；家具按功能组放置。</p><p>吸烟室随机出现、最多一间，只有一个侧廊入口，有长椅、烟灰桶、通风壁挂和外窗。墙边小色块为告示牌、消防箱、管线、门牌，不增加碰撞或地面占用。本轮不放落地布景。</p><p>每类 ${count} 个种子；点击查看完整 SVG。旧版输出保留，未接入游戏。</p>${sections}</html>`);
 fs.writeFileSync(path.join(out,'report.json'),JSON.stringify({generated:records.length,productionIntegrated:false,records},null,2));return records;
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const args=process.argv.slice(2),get=(name,fallback)=>{const i=args.indexOf(name);return i<0?fallback:args[i+1];};
 if(args.includes('--type')){const type=get('--type','V3'),seed=Number(get('--seed',1001)),out=get('--out','office-preview.svg'),d=generate(type,seed);fs.mkdirSync(path.dirname(path.resolve(out)),{recursive:true});fs.writeFileSync(out,svg(d));fs.writeFileSync(out.replace(/\.svg$/i,'')+'.json',JSON.stringify(d,null,2));console.log(`${type}/${seed}: validated, ${out}`);}
 else{const count=Number(get('--count',10)),start=Number(get('--seed',1001));if(!Number.isInteger(count)||count<1||count>100)throw Error('count must be 1..100');const records=batch(get('--out','.runtime/office_skeleton_preview'),count,start);console.log(`Generated and validated ${records.length} SVG whiteboxes; no production changes.`);}
}
