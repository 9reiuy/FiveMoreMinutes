import test from 'node:test';
import assert from 'node:assert/strict';
import {TYPES,generate,validate,svg} from './generator.mjs';

const samples=new Map();
test('combat-office frontages use continuous glass and open portals',()=>{
 const halls=new Set(['hub','ring','transition','flank','rear','lower','service','crosshall']);
 for(const type of TYPES){const data=generate(type,1001),fronts=data.doors.filter(d=>d.officeFrontage);
  assert.ok(fronts.length>=2,`${type} has multiple glass frontages`);
  for(const d of fronts){assert.ok(d.glass&&d.width>=2);assert.ok((['main','west','east'].includes(d.a)&&halls.has(d.b))||(['main','west','east'].includes(d.b)&&halls.has(d.a)));}
  const portals=data.doors.filter(d=>!d.glass&&((['main','west','east'].includes(d.a)&&halls.has(d.b))||(['main','west','east'].includes(d.b)&&halls.has(d.a))));
  assert.ok(portals.length);assert.ok(portals.every(d=>d.open));assert.ok(data.checks.ok);
 }
});
test('four skeletons, ten seeds each: reproducible valid layouts and variation',()=>{
 for(const type of TYPES){const shapes=new Set();for(let seed=1001;seed<=1010;seed++){
  const a=generate(type,seed),b=generate(type,seed);assert.deepEqual(a,b,`${type}/${seed} determinism`);
  assert.equal(a.checks.ok,true);assert.ok(a.rooms.some(r=>r.id==='inner'&&r.parent==='deep'));
  assert.equal(a.routes.length,3);assert.ok(a.doors.some(d=>d.glass));assert.ok(a.rooms.length>=10);
  assert.ok(a.enemies.every(e=>!['entry','lift'].includes(e.room)));
  const reception=a.rooms.find(r=>r.id==='entry');assert.deepEqual([reception.bounds.w,reception.bounds.h,reception.cells.length],[14,10,140]);
  assert.ok(a.furniture.every(f=>f.group&&Number.isInteger(f.member)));
  assert.ok(a.rooms.filter(r=>!['lift','hub','ring','flank','rear','lower','service','crosshall','transition'].includes(r.id)).every(r=>a.furniture.some(f=>f.room===r.id)));
  shapes.add(JSON.stringify(a.rooms.map(r=>[r.id,r.bounds])));samples.set(`${type}/${seed}`,a);
 }assert.equal(shapes.size,10,`${type} must vary geometry, not just color`);}
});
test('skeleton topology differs and progression has no entry-to-deep shortcut',()=>{
 const graphs=new Set();for(const type of TYPES){const d=generate(type,42);graphs.add(JSON.stringify(d.routes.map(r=>r.rooms)));
 assert.ok(!d.doors.some(p=>!p.glass&&[p.a,p.b].includes('entry')&&[p.a,p.b].includes('deep')));
 if(type==='B2')assert.ok(d.routes[0].rooms.includes('west')&&d.routes[0].rooms.includes('east'));
 if(type==='C3')assert.ok(d.routes[0].rooms.includes('transition'));
 }assert.equal(graphs.size,4);
});
test('mirrors exist without breaking any layout contract',()=>{
 const states=new Set();for(const d of samples.values()){states.add(d.mirror);assert.equal(validate(d).ok,true);}assert.equal(states.size,2);
});
test('blocking reserved corridor is rejected',()=>{
 const d=structuredClone(generate('V3',42)),[x,y]=d.routes[0].points[0].split(',').map(Number);
 d.furniture.push({room:'entry',kind:'bad',x,y,w:1,h:1});assert.equal(validate(d).ok,false);
});
test('solidifying the only nested doorway is rejected',()=>{
 const d=structuredClone(generate('B2',42));d.doors=d.doors.filter(p=>p.a!=='inner'&&p.b!=='inner');
 assert.equal(validate(d).ok,false);assert.ok(validate(d).errors.includes('nested room bypass'));
});
test('unsafe enemy and external furniture are rejected',()=>{
 const d=structuredClone(generate('A1',42));d.enemies.push({room:'entry',cell:d.anchors.entry});d.furniture.push({room:'main',x:-100,y:-100,w:1,h:1});
 assert.equal(validate(d).ok,false);assert.ok(validate(d).errors.includes('furniture outside room'));
});
test('SVG has floor, intact-glass semantics and preview disclaimer',()=>{
 const output=svg(generate('C3',42));assert.ok(output.startsWith('<svg'));assert.ok(output.endsWith('</svg>'));
 assert.ok(output.includes('未接入游戏'));assert.ok(output.includes('玻璃完整时按实墙检查'));
 assert.ok(!output.includes('NaN'));assert.ok(!output.includes('undefined'));
});
test('invalid input is rejected without silently switching skeleton',()=>{
 assert.throws(()=>generate('X',1));assert.throws(()=>generate('A1',-1));assert.throws(()=>generate('V3',1.3));
});
test('reception is fixed geometry and identical furniture template across skeletons',()=>{
 for(const d of samples.values()){
  const room=d.rooms.find(r=>r.id==='entry'),group=d.groups.find(g=>g.room==='entry');
  assert.equal(room.bounds.w,14);assert.equal(room.bounds.h,10);assert.equal(group.template,'reception');assert.equal(group.members,4);
  assert.ok(d.furniture.some(f=>f.room==='entry'&&f.kind==='接待台'&&f.facing[1]===1));
 }
 const d=structuredClone(generate('V3',42));d.rooms.find(r=>r.id==='entry').bounds.w=15;assert.ok(validate(d).errors.includes('reception size changed'));
});
test('moving one piece without transforming the group is rejected',()=>{
 const d=structuredClone(generate('B2',42)),f=d.furniture.find(f=>f.kind==='工作桌');f.x+=1;
 assert.ok(validate(d).errors.includes('group member scattered'));
});
test('six conference chairs face their table; reversing one seat is rejected',()=>{
 for(const d of samples.values())for(const group of d.groups.filter(g=>g.template==='conference')){
  assert.equal(d.furniture.filter(f=>f.group===group.id&&f.kind==='会议椅').length,6);
 }
 const d=structuredClone(generate('A1',42)),f=d.furniture.find(f=>f.kind==='会议椅');f.facing=f.facing.map(v=>-v);
 assert.ok(validate(d).errors.includes('seat faces away from table'));
});
test('one shared lounge coffee table and parallel workstation banks',()=>{
 for(const d of samples.values()){
  for(const r of d.rooms.filter(r=>r.kind==='lounge'))assert.equal(d.furniture.filter(f=>f.room===r.id&&f.kind==='矮茶几').length,1);
  for(const id of ['main','west','east']){const banks=d.groups.filter(g=>g.room===id&&g.template==='workstation');if(banks.length)assert.equal(new Set(banks.map(g=>g.turn)).size,1);}
 }
});
test('corridor width is measured from the actual floor segments',()=>{
 for(const d of samples.values())for(const s of d.corridorSegments){const[a,b]=s.class==='side'?[3,4]:s.class==='main'?[4,5]:[6,8];assert.ok(s.width>=a&&s.width<=b);assert.equal(Math.min(s.w,s.h),s.width);}
 const d=structuredClone(generate('V3',42));d.corridorSegments[0].w+=10;assert.equal(validate(d).ok,false);
});
test('smoking room is optional, at most one, and never required for the route',()=>{
 const states=new Set();for(const d of samples.values()){
  const room=d.rooms.find(r=>r.id==='smoking');states.add(Boolean(room));assert.equal(Boolean(room),d.smokingRequested);
  assert.ok(d.rooms.filter(r=>r.id==='smoking').length<=1);
  assert.ok(!d.routes.some(r=>r.rooms.includes('smoking')));
  if(room){assert.equal(d.doors.filter(p=>!p.glass&&(p.a==='smoking'||p.b==='smoking')).length,1);assert.ok(d.furniture.some(f=>f.room==='smoking'&&f.kind==='烟灰桶'));assert.ok(d.doors.some(p=>p.a==='smoking'&&p.exterior));}
 }assert.equal(states.size,2);
});
test('wall dressing has no floor collision and cannot overlap a doorway',()=>{
 for(const d of samples.values()){assert.ok(d.decor.length>0);assert.ok(d.decor.every(p=>p.wallMounted&&p.collision===false));}
 const d=structuredClone(generate('C3',42));d.decor[0].outside=d.decor[0].inside;assert.ok(validate(d).errors.includes('invalid wall decoration'));
});
test('newly attached negative-coordinate rooms preserve mirrored contracts',()=>{
 for(const d of samples.values())if(d.rooms.some(r=>r.id==='smoking'))assert.equal(validate(d).ok,true);
 const d=generate('B2',42);assert.ok(d.rooms.some(r=>r.id==='entry'&&r.bounds.w===14&&r.bounds.h===10));
});
