"""Exploratory model of two persistent FIFOs. Does not call filter2win.
Parameters and input histories live in the accompanying JSON.
No time eviction, no reset, no ground-truth input into route/activate logic.
"""
import json, math, csv, hashlib
from pathlib import Path
from collections import deque
from statistics import median
from reportlab.graphics.shapes import Drawing, String, Line, Rect, Circle
from reportlab.graphics.charts.lineplots import LinePlot
from reportlab.graphics import renderPDF
from reportlab.lib.colors import HexColor, Color
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
import pypdfium2 as pdfium

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/"runtime/filter2win_memory_scenarios"
CONFIG=ROOT/"matlab/tests/configs/filter2win_memory_experiments.json"
OUT.mkdir(exist_ok=True)
pdfmetrics.registerFont(TTFont("Chart", "C:/Windows/Fonts/arial.ttf"))
pdfmetrics.registerFont(TTFont("ChartBold", "C:/Windows/Fonts/arialbd.ttf"))
COLORS={"A":"#1677b8","B":"#e48b22","reject":"#b3404a","guard":"#148853","direct":"#8855aa","truth":"#313944"}
C=lambda x:HexColor(x)
def stats(q):
    if not q:return {"n":0,"center":None,"mad":None,"span":0}
    center=median(r["x"] for r in q)
    return {"n":len(q),"center":center,"mad":median(abs(r["x"]-center) for r in q),"span":q[-1]["t"]-q[0]["t"]}
def simulate(s,c,confirmation,policy="nearest",events=None):
    queues=[]
    for name in ["A","B"]:
        queues.append(deque({"id":name+"_pre_"+str(i),"t":t,"x":x} for i,(t,x) in enumerate(s["prehistory"][name])))
    active=0
    streak=[0,0]
    last_active=queues[0][-1]["t"]
    trace=[]
    for j,e in enumerate(events if events is not None else s["events"]):
        t,x=e["t"],e["x"]
        before=[stats(q) for q in queues]
        centers=[v["center"] for v in before]
        distances=[None,None]
        route=None; why="MISSING"; switch=False; evicted=None
        incoming_members=[False,False]
        if x is not None:
            for k in [0,1]:
                if centers[k] is not None:
                    distances[k]=abs(x-centers[k])/c["radii"][k]
                    incoming_members[k]=distances[k]<=1
            eligible=[k for k in [0,1] if incoming_members[k]]
            if len(eligible)==1:route=eligible[0]; why="ONLY_ONE_BAND"
            elif len(eligible)==2:
                tie=math.isclose(distances[0],distances[1],abs_tol=1e-12)
                route=active if policy=="active" or tie else min(eligible,key=lambda k:distances[k])
                why="OVERLAP_ACTIVE" if policy=="active" else ("TIE_ACTIVE" if tie else "OVERLAP_NEAREST")
            elif not queues[1]:
                route=1; why="SEED_EMPTY_B"
            else:why="OUTSIDE_BOTH"
            if route is not None:
                q=queues[route]
                if len(q)>=c["capacity"]:evicted=q.popleft()["id"]
                q.append({"id":["A","B"][route]+"_"+str(j),"t":t,"x":x})
                if route==active:
                    last_active=t; streak=[0,0]
                else:
                    streak[route]+=1; streak[active]=0
                    v=stats(q)
                    ready=v["n"]>=c["min_samples"] and v["span"]>=c["min_span_seconds"] and v["mad"]<=c["max_mad"]
                    if ready and streak[route]>=confirmation:
                        active=route; switch=True; last_active=t; streak=[0,0]
            else:streak=[0,0]
        elif c["missing_confirmation"]=="reset":streak=[0,0]
        after=[stats(q) for q in queues]
        v=after[active]
        valid=v["n"]>=c["min_samples"] and v["span"]>=c["min_span_seconds"] and v["mad"]<=c["max_mad"] and t-last_active<=c["hold_seconds"]
        trace.append({"t":t,"x":x,"truth":e["truth"],"route":None if route is None else ["A","B"][route],"reason":why,
            "active":["A","B"][active],"switch":switch,"output":v["center"] if valid else None,
            "gate_center_A":centers[0],"gate_center_B":centers[1],
            "count_A":after[0]["n"],"count_B":after[1]["n"],"center_A":after[0]["center"],"center_B":after[1]["center"],
            "span_A":after[0]["span"],"span_B":after[1]["span"],"mad_A":after[0]["mad"],"mad_B":after[1]["mad"],
            "distance_A":distances[0],"distance_B":distances[1],"in_A":incoming_members[0],"in_B":incoming_members[1],
            "evicted":evicted,"ids_A":[r["id"] for r in queues[0]],"ids_B":[r["id"] for r in queues[1]]})
    return trace

def segments(trace,key):
    result=[]; current=[]
    for r in trace:
        if r[key] is None:
            if len(current)>1:result.append(current)
            current=[]
        else: current.append((r["t"],r[key]))
    if len(current)>1:result.append(current)
    return result
def stair(points):
    out=[points[0]]
    for p in points[1:]:
        out.append((p[0],out[-1][1]));out.append(p)
    return out

def label(d,x,y,text,size=10,color="#263345",bold=False):
    d.add(String(x,y,text,fontName="ChartBold" if bold else "Chart",fontSize=size,fillColor=C(color)))
def plot(d,x,y,w,h,xmin,xmax,ymin,ymax,series,xlabel=True):
    p=LinePlot(); p.x=x;p.y=y;p.width=w;p.height=h
    p.data=[stair(points) for points,color,width,dash in series]
    p.xValueAxis.valueMin=xmin;p.xValueAxis.valueMax=xmax
    p.yValueAxis.valueMin=ymin;p.yValueAxis.valueMax=ymax
    for axis in [p.xValueAxis,p.yValueAxis]:
        axis.labels.fontName="Chart";axis.labels.fontSize=8;axis.strokeColor=C("#b3beca")
        axis.visibleGrid=True;axis.gridStrokeColor=C("#e7ecf1");axis.gridStrokeWidth=0.4
    if not xlabel:p.xValueAxis.labels.visible=False
    for i,(_,color,width,dash) in enumerate(series):
        p.lines[i].strokeColor=C(color);p.lines[i].strokeWidth=width
        if dash:p.lines[i].strokeDashArray=dash
    d.add(p)
    return lambda t,v:(x+(t-xmin)/(xmax-xmin)*w,y+(v-ymin)/(ymax-ymin)*h)
def render(s,c,direct,guard,name,subtitle="",extra=None):
    d=Drawing(1000,650)
    d.add(Rect(0,0,1000,650,fillColor=C("#ffffff"),strokeColor=None))
    label(d,62,618,s["id"]+"  "+s["title"],17,bold=True)
    label(d,62,596,"СЦЕНАРНАЯ МОДЕЛЬ · производственное ядро filter2win не запускалось",10,"#9a4b24")
    label(d,62,578,subtitle or "Оба FIFO сохраняются. Сравнение: готовое окно сразу / 3 последовательных попадания; обрыв сохраняет подтверждение.",10)
    xmin=min(r["t"] for r in guard);xmax=max(r["t"] for r in guard)
    vals=[r[k] for r in guard for k in ["x","center_A","center_B","truth"] if r[k] is not None]
    ymin=min(vals)-3;ymax=max(vals)+3
    series=[([(r["t"],r["truth"]) for r in guard],COLORS["truth"],1,[3,3])]
    for key,color in [("output",COLORS["direct"])]:
        series.extend((seg,color,1.4,[5,3]) for seg in segments(direct,key))
    series.extend((seg,COLORS["guard"],2,None) for seg in segments(guard,"output"))
    for k in [0,1]:
        key=["gate_center_A","gate_center_B"][k]; color=COLORS[["A","B"][k]]
        for sign in [-1,1]:
            points=[(r["t"],r[key]+sign*c["radii"][k]) for r in guard if r[key] is not None]
            if len(points)>1:series.append((points,color,0.55,[2,3]))
    xy=plot(d,62,265,900,288,xmin,xmax,ymin,ymax,series,False)
    for r in guard:
        if r["x"] is not None:
            xx,yy=xy(r["t"],r["x"]); color=COLORS.get(r["route"],COLORS["reject"])
            if r["route"] is None:
                d.add(Line(xx-3,yy-3,xx+3,yy+3,strokeColor=C(color),strokeWidth=1.3))
                d.add(Line(xx-3,yy+3,xx+3,yy-3,strokeColor=C(color),strokeWidth=1.3))
            else:d.add(Circle(xx,yy,2.8,fillColor=C(color),strokeColor=C("#ffffff"),strokeWidth=0.4))
    # A finite output at a single isolated tick must also be visible.
    for source,color in [(direct,COLORS["direct"]),(guard,COLORS["guard"])]:
        for i,r in enumerate(source):
            if r["output"] is not None and (i==0 or source[i-1]["output"] is None) and (i==len(source)-1 or source[i+1]["output"] is None):
                xx,yy=xy(r["t"],r["output"])
                d.add(Circle(xx,yy,4.5,fillColor=None,strokeColor=C(color),strokeWidth=1.5))
    for r in guard:
        if r["switch"]:
            xx,_=xy(r["t"],ymin);d.add(Line(xx,265,xx,553,strokeColor=C("#99b5a2"),strokeDashArray=[2,4],strokeWidth=0.7))
            label(d,min(xx+3,905),541,"→"+r["active"],8,"#176d48")
    label(d,10,556,"Значение, км",9)
    # bottom plot: persistent occupancy
    series=[([(r["t"],r["count_A"]) for r in guard],COLORS["A"],1.5,None),
            ([(r["t"],r["count_B"]) for r in guard],COLORS["B"],1.5,None),
            ([(xmin,c["min_samples"]),(xmax,c["min_samples"])],"#687789",0.8,[3,3])]
    plot(d,62,105,900,112,xmin,xmax,0,c["capacity"]+1,series)
    label(d,62,233,"Число точек в FIFO · пунктир — минимум для готовности",10,bold=True)
    label(d,850,78,"Время, с",9)
    legend=[("Точка → A",COLORS["A"]),("Точка → B",COLORS["B"]),("× отклонена",COLORS["reject"]),("3 попадания",COLORS["guard"]),("Сразу",COLORS["direct"]),("Истина",COLORS["truth"])]
    if name.endswith("_gap"):
        legend[3]=("Заново после паузы",COLORS["guard"]);legend[4]=("Сохранить",COLORS["direct"])
    if name.endswith("_routing"):
        legend[3]=("Ближайшая",COLORS["guard"]);legend[4]=("Активная",COLORS["direct"])
    for i,(text,color) in enumerate(legend):
        xx=62+i*151;d.add(Line(xx,57,xx+15,57,strokeColor=C(color),strokeWidth=2));label(d,xx+20,54,text,9)
    label(d,62,33,"Границы окрестностей показаны тонким пунктиром; цвет точек — маршрутизация варианта «3 попадания».",9,"#586678")
    pdf=OUT/(name+".pdf");renderPDF.drawToFile(d,str(pdf))
    pdfdoc=pdfium.PdfDocument(str(pdf));page=pdfdoc[0];bitmap=page.render(scale=1.6)
    bitmap.to_pil().save(OUT/(name+".png"))
    bitmap.close();page.close();pdfdoc.close()

def summary(trace):
    return {"switches":[{"t":r["t"],"to":r["active"]} for r in trace if r["switch"]],
        "routes":{k:sum(r["route"]==k for r in trace if r["x"] is not None) for k in ["A","B",None]},
        "final_counts":[trace[-1]["count_A"],trace[-1]["count_B"]],
        "evictions":sum(r["evicted"] is not None for r in trace)}
def write_csv(name,trace):
    fields=list(trace[0])
    with (OUT/(name+".csv")).open("w",encoding="utf-8-sig",newline="") as f:
        writer=csv.DictWriter(f,fieldnames=fields);writer.writeheader()
        for row in trace:writer.writerow({k:json.dumps(v,ensure_ascii=False) if isinstance(v,list) else v for k,v in row.items()})
def main():
    data=json.loads(CONFIG.read_text(encoding="utf-8"))
    all_results={}
    for s in data["scenarios"]:
        c=dict(data["base"],**s.get("overrides",{}))
        direct=simulate(s,c,1);guard=simulate(s,c,3)
        render(s,c,direct,guard,"scenario_"+s["id"])
        write_csv("scenario_"+s["id"]+"_direct",direct);write_csv("scenario_"+s["id"]+"_guard",guard)
        result={"direct":summary(direct),"guard":summary(guard),"purpose":s["purpose"]}
        if "paired_events" in s:
            slow1=simulate(s,c,1,events=s["paired_events"]);slow3=simulate(s,c,3,events=s["paired_events"])
            render(s,c,slow1,slow3,"scenario_"+s["id"]+"_slow","Те же 6 значений, но за 20 секунд; минимум длительности базы — 8 секунд.")
            write_csv("scenario_"+s["id"]+"_slow",slow3);result["slow_guard"]=summary(slow3)
        if s.get("compare_routing"):
            alternate=simulate(s,c,3,"active")
            write_csv("scenario_"+s["id"]+"_active_priority",alternate)
            render(s,c,alternate,guard,"scenario_"+s["id"]+"_routing","Зелёный: ближайшая модель; фиолетовый: приоритет активной. Оба варианта требуют 3 попадания.")
            result["routing_comparison"]=[{"t":a["t"],"x":a["x"],"nearest":a["route"],"active_priority":b["route"],"reason":a["reason"]} for a,b in zip(guard,alternate)]
        if s.get("compare_confirmation_gap"):
            fresh=simulate(s,dict(c,missing_confirmation="reset"),3)
            render(s,c,guard,fresh,"scenario_"+s["id"]+"_gap","FIFO одинаковы. Фиолетовый: сохранить подтверждение; зелёный: подтвердить заново после обрыва.")
            write_csv("scenario_"+s["id"]+"_gap_reset",fresh)
            result["gap_reset_guard"]=summary(fresh)
        # Record direct invariants as evidence, not a production PASS.
        gap_unchanged=all(r["ids_A"]==guard[i-1]["ids_A"] and r["ids_B"]==guard[i-1]["ids_B"] for i,r in enumerate(guard) if i and r["x"] is None)
        result["memory_observation"]={"no_mutation_on_missing":gap_unchanged,
            "max_counts":[max(r["count_A"] for r in guard),max(r["count_B"] for r in guard)]}
        all_results[s["id"]]=result
    report={"kind":"exploratory_model_observations","production_kernel_executed":False,
        "config_sha256":hashlib.sha256(CONFIG.read_bytes()).hexdigest(),
        "script_sha256":hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),"scenarios":all_results}
    (OUT/"observations.json").write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
    # Multi-panel overview assembled from these new computed charts.
    from PIL import Image, ImageOps, ImageDraw, ImageFont
    pages=[Image.open(OUT/("scenario_"+s["id"]+".png")).convert("RGB") for s in data["scenarios"]]
    width=1000; height=650
    overview=Image.new("RGB",(width*2,height*math.ceil(len(pages)/2)),"white")
    for i,p in enumerate(pages):overview.paste(p.resize((width,height)),((i%2)*width,(i//2)*height))
    overview.save(OUT/"overview.png")
    print(json.dumps({k:{"switches_1":v["direct"]["switches"],"switches_3":v["guard"]["switches"],"counts":v["guard"]["final_counts"],"rejected":v["guard"]["routes"].get(None,v["guard"]["routes"].get("null"))} for k,v in all_results.items()},ensure_ascii=False))
if __name__=="__main__":main()
