// Furniture prototypes for the offline whitebox, not production asset definitions.
const key=(x,y)=>`${x},${y}`;
const rect=(x,y,w,h)=>{const a=[];for(let j=y;j<y+h;j++)for(let i=x;i<x+w;i++)a.push(key(i,j));return a;};
const piece=(kind,x,y,w,h,high=false,facing=null,target=null)=>({kind,x,y,w,h,high,facing,target});
export const templates={
 reception:[piece('接待台',1,6,4,2,true,[0,1]),piece('办公椅',2,4,1,1,false,[0,1],0),piece('矮茶几',9,6,1,2),piece('等候沙发',11,6,2,2,false,[-1,0],2)],
 workstation:[piece('工作桌',0,0,3,2),piece('工作桌',0,2,3,2),piece('办公椅',1,-2,1,1,false,[0,1],0),piece('办公椅',1,5,1,1,false,[0,-1],1)],
 conference:[piece('会议桌',0,0,5,3),...[-2,4].flatMap((y)=>[0,2,4].map(x=>piece('会议椅',x,y,1,1,false,[0,y<0?1:-1],0)))],
 desk:[piece('办公桌',0,0,4,2),piece('办公椅',1,3,1,1,false,[0,-1],0)],
 archive:[piece('档案柜',0,0,2,4,true,[1,0]),piece('档案柜',5,0,2,4,true,[-1,0])],
 server:[piece('机柜',0,0,2,4,true,[1,0]),piece('机柜',5,0,2,4,true,[-1,0])],
 lounge:[piece('矮茶几',3,3,2,2),piece('沙发',2,0,4,1,false,[0,1],0),piece('沙发',0,2,1,4,false,[1,0],0)],
 counter:[piece('冰箱',0,0,1,2,true,[0,1]),piece('水槽台面',1,0,2,1,true,[0,1]),piece('咖啡台面',3,0,2,1,true,[0,1])],
 dining:[piece('餐桌',0,0,3,2),piece('餐椅',1,-2,1,1,false,[0,1],0),piece('餐椅',1,3,1,1,false,[0,-1],0)],
 print:[piece('打印机',0,0,2,2,true,[0,1]),piece('整理台',3,0,3,1)],
 shelf:[piece('文件柜',0,0,1,3,true,[1,0])],
 storage:[piece('整理台',0,0,1,2)],
 smoking:[piece('靠墙长椅',0,0,4,1,false,[0,1]),piece('烟灰桶',5,0,1,1)],
};
function transform(items,turn){
 let result=items.map(p=>({...p,facing:p.facing&&[...p.facing]}));
 for(let i=0;i<turn;i++)result=result.map(p=>({...p,x:-p.y-p.h,y:p.x,w:p.h,h:p.w,facing:p.facing&&[-p.facing[1],p.facing[0]]}));
 const minx=Math.min(...result.map(p=>p.x)),miny=Math.min(...result.map(p=>p.y));
 return result.map(p=>({...p,x:p.x-minx,y:p.y-miny}));
}
function footprint(items){return{w:Math.max(...items.map(p=>p.x+p.w)),h:Math.max(...items.map(p=>p.y+p.h))};}

export function furnish(rooms,doors,rand,halls){
 const items=[],groups=[],occupied=new Set(),doorBuffer=new Set();
 const owner=new Map([...rooms.values()].flatMap(r=>[...r.cells].map(c=>[c,r.id])));
 for(const d of doors.filter(d=>!d.glass))for(const c of d.cells){const[x,y]=c.split(',').map(Number);for(let off=-2;off<=2;off++)doorBuffer.add(d.vertical?key(x+off,y):key(x,y+off));}
 // A group candidate must leave all doorway approaches joined by a 3-cell-wide route.
 function roomClear(room,extra){
  const blocked=new Set([...occupied,...extra]),clear=new Set();
  for(const c of room.cells){const[x,y]=c.split(',').map(Number);if(rect(x-1,y-1,3,3).every(q=>room.cells.has(q)&&!blocked.has(q)))clear.add(c);}
  const approaches=[];
  for(const d of doors.filter(d=>!d.glass&&(d.a===room.id||d.b===room.id))){
   const cells=d.cells.filter(c=>owner.get(c)===room.id);const c=cells[Math.floor(cells.length/2)], [x,y]=c.split(',').map(Number);
   const p=d.vertical?key(x+(x===d.line?2:-2),y):key(x,y+(y===d.line?2:-2));approaches.push(p);
  }
  if(!approaches.length||approaches.some(c=>!clear.has(c)))return false;
  const queue=[approaches[0]],seen=new Set(queue);
  for(let i=0;i<queue.length;i++){const[x,y]=queue[i].split(',').map(Number);for(const[dx,dy]of [[1,0],[-1,0],[0,1],[0,-1]]){const c=key(x+dx,y+dy);if(clear.has(c)&&!seen.has(c)){seen.add(c);queue.push(c);}}}
  return approaches.every(c=>seen.has(c));
 }
 for(const room of rooms.values()){
  if(halls.has(room.id)||room.id==='lift')continue;
  const b=room.bounds;
  function place(name,mode='center',required=true,forcedTurn=null){
   const turns=forcedTurn===null?[0,1,2,3]:[forcedTurn],candidates=[];
   for(const turn of turns){const local=transform(templates[name],turn),size=footprint(local);
    if(name==='reception'){candidates.push({x:b.x,y:b.y,local:templates.reception.map(p=>({...p})),size:{w:14,h:10},turn:0,score:0});break;}
    for(let y=b.y+1;y<=b.y+b.h-size.h-1;y++)for(let x=b.x+1;x<=b.x+b.w-size.w-1;x++){
     // Workstation banks use a common aligned lattice, not unrelated per-piece scatter.
     if(name==='workstation'&&((x-b.x-1)%(size.w+3)!==0||(y-b.y-1)%(size.h+3)!==0))continue;
     const prior=groups.find(g=>g.room===room.id&&g.template===name);
     if(mode==='rows'&&prior&&x!==prior.x)continue;
     if(mode==='wall'&&local.some(p=>p.facing&&(p.high||p.target===null)&&((b.x+b.w/2-x-p.x-p.w/2)*p.facing[0]+(b.y+b.h/2-y-p.y-p.h/2)*p.facing[1])<0))continue;
     const central=Math.abs(x+size.w/2-b.x-b.w/2)+Math.abs(y+size.h/2-b.y-b.h/2);
     const wall=Math.min(x-b.x,y-b.y,b.x+b.w-x-size.w,b.y+b.h-y-size.h);
     const score=(mode==='wall'?wall*100+central:mode==='bank'?y*2+x*.1:central)+rand()*.2;
     candidates.push({x,y,local,size,turn,score});
    }
   }
   candidates.sort((a,b)=>a.score-b.score);
   for(const candidate of candidates){const{x,y,local,size,turn}=candidate;
    const world=local.map(p=>({...p,x:x+p.x,y:y+p.y})),cells=world.flatMap(p=>rect(p.x,p.y,p.w,p.h));
    if(cells.some(c=>!room.cells.has(c)||doorBuffer.has(c)||occupied.has(c)))continue;
    if(name!=='reception'&&world.some(p=>rect(p.x-2,p.y-2,p.w+4,p.h+4).some(c=>occupied.has(c))))continue;
    if(!roomClear(room,cells))continue;
    const id=`${room.id}:${groups.filter(g=>g.room===room.id).length}`;
    for(let i=0;i<world.length;i++){const p=world[i],target=p.target===null?null:world[p.target];
     items.push({...p,room:room.id,group:id,member:i,target:target?{x:target.x+target.w/2,y:target.y+target.h/2}:null});
    }
    cells.forEach(c=>occupied.add(c));groups.push({id,room:room.id,template:name,x,y,w:size.w,h:size.h,turn,members:world.length});return true;
   }
   if(required)throw Error(`functional group cannot fit ${room.id}:${name}`);return false;
  }
  if(room.id==='entry'){if(b.w!==14||b.h!==10)throw Error('reception must be 14x10');place('reception');continue;}
  if(['main','west','east'].includes(room.id)){
   const turn=rand()<.5?0:1;place('workstation','bank',true,turn);
   for(let i=1;i<Math.max(2,Math.floor(room.cells.size/85));i++)if(!place('workstation','bank',false,turn))break;
   place('shelf','wall');
  }else if(['meeting','training'].includes(room.kind)){place('conference');place('shelf','wall',false);}
  else if(['archive','server'].includes(room.kind)){place(room.kind,'center');const first=groups.find(g=>g.room===room.id&&g.template===room.kind);place(room.kind,'rows',false,first.turn);}
  else if(room.kind==='lounge'){place('lounge');place('shelf','wall',false);}
  else if(room.kind==='pantry'){place('counter','wall');place('dining');}
  else if(room.kind==='print'){place('print','wall');}
  else if(room.kind==='storage'){place('storage','wall');}
  else if(room.kind==='smoking'){place('smoking','wall');}
  else {place('desk');place('shelf','wall',room.id==='inner');if(room.id==='deep')place('lounge','center',false);}
 }
 return {items,groups,occupied};
}

export function validateGroups(data){
 const errors=[],groups=new Map((data.groups||[]).map(g=>[g.id,g]));
 for(const item of data.furniture){const g=groups.get(item.group);if(!g||g.room!==item.room)errors.push('ungrouped furniture');
  if(g&&(item.x<g.x||item.y<g.y||item.x+item.w>g.x+g.w||item.y+item.h>g.y+g.h))errors.push('group transform broken');
  if(item.target){const dx=item.target.x-item.x-item.w/2,dy=item.target.y-item.y-item.h/2,d=Math.hypot(dx,dy),dot=(dx*item.facing[0]+dy*item.facing[1])/d;if(dot<.8)errors.push('seat faces away from table');}
 }
 for(const g of groups.values())if(data.furniture.filter(f=>f.group===g.id).length!==g.members)errors.push('incomplete functional group');
 // Enforce the template transform itself, not just a shared group name around scattered pieces.
 for(const g of groups.values()){
  const source=templates[g.template];if(!source){errors.push('unknown functional group');continue;}
  const expected=g.template==='reception'?source:transform(source,g.turn);
  for(let i=0;i<expected.length;i++){
   const p=expected[i],members=data.furniture.filter(f=>f.group===g.id&&f.member===i),f=members[0];
   const x=g.x+(g.mirror?g.w-p.x-p.w:p.x),y=g.y+p.y;
   if(members.length!==1||!f||f.x!==x||f.y!==y||f.w!==p.w||f.h!==p.h||f.kind!==p.kind){errors.push('group member scattered');continue;}
   if(p.facing&&(!f.facing||f.facing[0]!==p.facing[0]*(g.mirror?-1:1)||f.facing[1]!==p.facing[1]))errors.push('group facing transform broken');
   if(p.target!==null){const target=data.furniture.find(q=>q.group===g.id&&q.member===p.target);if(!target||!f.target||f.target.x!==target.x+target.w/2||f.target.y!==target.y+target.h/2)errors.push('seat target detached');}
  }
 }
 const entry=data.rooms.find(r=>r.id==='entry');if(!entry||entry.bounds.w!==14||entry.bounds.h!==10||entry.cells.length!==140)errors.push('reception size changed');
 for(const room of data.rooms){const gs=[...groups.values()].filter(g=>g.room===room.id);
  if(room.id==='entry'&&(gs.length!==1||gs[0].template!=='reception'))errors.push('reception layout changed');
  if(['main','west','east'].includes(room.id)&&!gs.some(g=>g.template==='workstation'))errors.push('missing workstation bank');
  if(['meeting','training'].includes(room.kind)&&!gs.some(g=>g.template==='conference'))errors.push('missing conference group');
  if(['archive','server'].includes(room.kind)&&!gs.some(g=>g.template===room.kind))errors.push('missing cabinet columns');
  if(room.kind==='pantry'&&(!gs.some(g=>g.template==='counter')||!gs.some(g=>g.template==='dining')))errors.push('missing pantry functional group');
  if(room.kind==='smoking'&&!gs.some(g=>g.template==='smoking'))errors.push('missing smoking functional group');
  if(room.id==='inner'&&(!gs.some(g=>g.template==='desk')||!gs.some(g=>g.template==='shelf')))errors.push('missing manager functional group');
  if(room.kind==='lounge'&&(gs.filter(g=>g.template==='lounge').length!==1||data.furniture.filter(f=>f.room===room.id&&f.kind==='矮茶几').length!==1))errors.push('lounge needs one shared coffee table');
 }
 return [...new Set(errors)];
}
