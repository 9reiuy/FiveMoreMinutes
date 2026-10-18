"""Keep functional results separate from measured workload and budget failures."""
import json
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
def messages(path, prefix):
    data=path.read_bytes()
    text=data.decode("utf-16" if data[:2] in [b"\xff\xfe",b"\xfe\xff"] else "utf-8-sig", errors="replace")
    rows=[]
    for line in text.splitlines():
        if prefix in line:
            value=line.split(prefix,1)[1].strip()
            if value.startswith("{"): rows.append(json.loads(value))
    return rows

result={"combat":{},"budget_passed":None,"medium_hardware":"pending physical machine"}
for name in ["A1","B2","C3","V3","V3_retry","A1_off"]:
    log=root/f"combat_{name}.log"
    if not log.exists(): continue
    perf=messages(log,"RANDOM_COMBAT_PERF ")
    budget=messages(log,"RANDOM_COMBAT_ACCEPTANCE ")
    if not perf: continue
    perf=perf[-1]
    result["combat"][name]={"performance":perf,"budget":budget[-1] if budget else None,"valid_workload":perf["enemy_shooters"]>=2 and perf["shots"]["enemy"]>=10 and perf["shots"]["player"]>=10 and perf["distance"]>=500}
for key, path in [("soak","soak/formal_acceptance.json"),("functional","regression_final/results.json"),("camera","camera_visual/report.json"),("occlusion_blood_pause","sample_final/report.json")]:
    file=root/path
    if file.exists():
        data=json.loads(file.read_text(encoding="utf-8-sig"))
        if isinstance(data,dict) and "clips" in data: data={k:v for k,v in data.items() if k!="clips"}
        result[key]=data
required=["A1","B2","C3","V3_retry"]
if all(k in result["combat"] for k in required) and "soak" in result:
    result["budget_passed"]=all(result["combat"][k]["valid_workload"] and result["combat"][k]["budget"] and result["combat"][k]["budget"]["passed"] for k in required) and result["soak"]["failures"]==0
(root/"summary.json").write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding="utf-8")
print(json.dumps({"combat_workloads":{k:v["valid_workload"] for k,v in result["combat"].items()},"budget_passed":result["budget_passed"],"artifacts":list(result)},ensure_ascii=False))
