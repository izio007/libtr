"""Exploratory scalar filter for synthetic estimates of a stationary target.
No production kernel or physical optimizer is executed.
"""
from pathlib import Path
from statistics import median
import json,csv,hashlib,math
from reportlab.graphics.shapes import Drawing,Rect,Line,Circle
from reportlab.graphics import renderPDF
import pypdfium2 as pdfium
from PIL import Image
from filter2win_memory_experiments import label,plot,C,segments
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/"runtime/filter2win_memory_scenarios/optimizer_stationary"
CFG=ROOT/"matlab/tests/configs/filter2win_optimizer_experiments.json"

def features(rows):
    if not rows:return dict(n=0,center=None,mad=None,span=0,width=None)
    m=median(r["x"] for r in rows)
    return dict(n=len(rows),center=m,mad=median(abs(r["x"]-m) for r in rows),
                span=max(r["t"] for r in rows)-min(r["t"] for r in rows),
                width=max(r["x"] for r in rows)-min(r["x"] for r in rows))
def clean(rows,c):
    raw=features(rows)
    if len(rows)<c["trim_min_samples"]:
        return rows,[],raw,None
    limit=c["trim_k"]*max(c["sigma_floor"],c["mad_scale"]*raw["mad"])
    kept=[r for r in rows if abs(r["x"]-raw["center"])<=limit]
    removed=[r["id"] for r in rows if abs(r["x"]-raw["center"])>limit]
    return kept,removed,raw,limit
def good(f,c):
    return f["n"]>0 and f["mad"]<=c["max_mad"] and f["width"]<=c["max_range"]
def ready(f,c):
    return f["n"]>=c["min_samples"] and f["span"]>=c["min_span_seconds"] and good(f,c)
def simulate(s,c):
    queues=[[dict(id=w+"_pre_"+str(i),t=t,x=x) for i,(t,x) in enumerate(s["prehistory"][w])] for w in ["A","B"]]
    active=0;last_active=queues[0][-1]["t"];trace=[]
    for i,e in enumerate(s["events"]):
        t,x=e["t"],e["x"];fs=[features(q) for q in queues]
        isready=[ready(f,c) for f in fs]
        chosen=None;route=None;why="MISSING";removed=[];evicted=None;score=None;switch=False
        distances=[None,None];raw=None;limit=None;f=None
        if x is not None:
            candidates=[]
            for k in [0,1]:
                if isready[k]:
                    distances[k]=abs(x-fs[k]["center"])/c["radii"][k]
                    if distances[k]<=1:candidates.append(k)
            if len(candidates)==1:chosen=candidates[0];why="READY_BAND"
            elif len(candidates)==2:
                chosen=active if math.isclose(distances[0],distances[1],abs_tol=1e-12) else min(candidates,key=lambda k:distances[k])
                why="OVERLAP"
            elif not isready[1]:
                chosen=1;why="COLLECT_UNREADY_B"
            else:why="OUTSIDE_BOTH"
            if chosen is not None:
                q=queues[chosen];newid=["A","B"][chosen]+"_"+str(i)
                proposed=q+[dict(id=newid,t=t,x=x)]
                overflow=None
                if len(proposed)>c["capacity"]:overflow=proposed.pop(0)["id"]
                kept,excluded,raw,limit=clean(proposed,c)
                f=features(kept)
                score=max(f["mad"]/c["max_mad"],f["width"]/c["max_range"]) if f["n"] else None
                if limit is not None:score=max(score or 0,abs(x-raw["center"])/limit)
                new_removed=newid in excluded
                if new_removed or (isready[chosen] and not good(f,c)):
                    why="REJECT_NEW_EXTREME" if new_removed else "REJECT_SPREAD"
                else:
                    queues[chosen]=kept;route=["A","B"][chosen];removed=excluded;evicted=overflow
                    if ready(f,c):
                        if chosen!=active:active=chosen;switch=True
                        last_active=t
                    why="ACCEPT_READY" if ready(f,c) else "COLLECTING_NOT_USED"
        after=[features(q) for q in queues]
        output=after[active]["center"] if ready(after[active],c) and t-last_active<=c["hold_seconds"] else None
        trace.append(dict(t=t,x=x,truth=e["truth"],source_for_review=e["source_for_review"],
            route=route,reason=why,active=["A","B"][active],switch=switch,output=output,
            nA=after[0]["n"],nB=after[1]["n"],madA=after[0]["mad"],madB=after[1]["mad"],
            centerA=after[0]["center"],centerB=after[1]["center"],readyA=ready(after[0],c),readyB=ready(after[1],c),
            spanA=after[0]["span"],spanB=after[1]["span"],
            proposed_stats=f,proposed_raw_stats=raw,outlier_limit=limit,
            distances=distances,proposed_score=score,removed=removed,evicted=evicted,
            idsA=[r["id"] for r in queues[0]],idsB=[r["id"] for r in queues[1]]))
    return trace
def chart(s,c,tr):
    d=Drawing(1000,780);d.add(Rect(0,0,1000,780,fillColor=C("#ffffff"),strokeColor=None))
    label(d,62,750,s["id"]+"  "+s["title"],17,bold=True)
    label(d,62,729,"Неподвижная цель · синтетические оценки оптимизатора · исследовательская модель",10,"#945522")
    label(d,62,712,"Зрелое окно используется сразу. Пропуски сохраняют базы; выявленные крайние выбросы удаляются.",10)
    xmin=tr[0]["t"];xmax=tr[-1]["t"]
    values=[r[k] for r in tr for k in ["x","truth","output"] if r[k] is not None]
    ymin=min(values)-1.5;ymax=max(values)+1.5
    series=[([(r["t"],r["truth"]) for r in tr],"#263645",1.2,[4,3])]
    series += [(seg,"#138451",2,None) for seg in segments(tr,"output")]
    xy=plot(d,62,396,900,293,xmin,xmax,ymin,ymax,series,False)
    for i,r in enumerate(tr):
        if r["output"] is not None and (i==0 or tr[i-1]["output"] is None) and (i==len(tr)-1 or tr[i+1]["output"] is None):
            xx,yy=xy(r["t"],r["output"]);d.add(Circle(xx,yy,4,fillColor=None,strokeColor=C("#138451"),strokeWidth=1.5))
        if r["x"] is not None:
            xx,yy=xy(r["t"],r["x"]);color="#1677b8" if r["route"]=="A" else "#e48b22" if r["route"]=="B" else "#bd3345"
            if r["route"] is not None:d.add(Circle(xx,yy,2.5,fillColor=C(color),strokeColor=None))
            else:
                d.add(Line(xx-3,yy-3,xx+3,yy+3,strokeColor=C(color),strokeWidth=1.4))
                d.add(Line(xx-3,yy+3,xx+3,yy-3,strokeColor=C(color),strokeWidth=1.4))
        if r["switch"]:
            xx,_=xy(r["t"],ymin);d.add(Line(xx,396,xx,689,strokeColor=C("#a7bbac"),strokeDashArray=[2,4],strokeWidth=.6))
            label(d,min(xx+3,925),677,"→"+r["active"],8,"#176d48")
        if r["removed"]:
            xx,_=xy(r["t"],ymin);label(d,min(xx+2,850),406,"удалено "+str(len(r["removed"])),8,"#bd3345")
    for r in tr:
        for point_id in r["removed"]:
            parts=point_id.split("_")
            if len(parts)==2:
                old=tr[int(parts[1])];xx,yy=xy(old["t"],old["x"])
                d.add(Circle(xx,yy,5,fillColor=None,strokeColor=C("#9056a3"),strokeWidth=1.5))
    label(d,9,699,"Координата, км",8)
    label(d,62,375,"Статистика, хранимая в FIFO: A — синяя, B — оранжевая",10,bold=True)
    series=[([(r["t"],r["nA"]) for r in tr],"#1677b8",1.4,None),
            ([(r["t"],r["nB"]) for r in tr],"#e48b22",1.4,None),
            ([(xmin,c["min_samples"]),(xmax,c["min_samples"])],"#73808e",.8,[3,3])]
    plot(d,62,245,900,113,xmin,xmax,0,c["capacity"]+1,series,False)
    label(d,62,223,"Проверка добавляемой точки и разброса: выше 1 — превышение; пики за шкалой подписаны",10,bold=True)
    points=[(r["t"],r["proposed_score"]) for r in tr if r["proposed_score"] is not None]
    maxscore=min(5,max([v for t,v in points]+[1])*1.1)
    xyq=plot(d,62,95,900,109,xmin,xmax,0,maxscore,[([(xmin,1),(xmax,1)],"#bd3345",.8,[3,3])])
    for r in tr:
        if r["proposed_score"] is not None:
            xx,yy=xyq(r["t"],min(r["proposed_score"],maxscore*.95))
            if r["proposed_score"]>maxscore:label(d,min(xx,920),yy+4,format(r["proposed_score"],".0f"),7,"#bd3345")
            d.add(Circle(xx,yy,2,fillColor=C("#bd3345" if r["route"] is None else "#596e80"),strokeColor=None))
    label(d,850,69,"Время, с; сетка нерегулярная",9)
    for i,(text,color) in enumerate([("Оценка → A","#1677b8"),("Оценка → B","#e48b22"),("× отклонена","#bd3345"),("Выход","#138451"),("Истина","#263645"),("Удалена из FIFO","#9056a3")]):
        x=62+i*149;d.add(Line(x,49,x+15,49,strokeColor=C(color),strokeWidth=2));label(d,x+20,46,text,9)
    label(d,62,24,"Метка «удалено» относится к старым крайним точкам. Новая отклонённая точка FIFO не меняет.",9,"#586678")
    name=s["id"];pdf=OUT/(name+".pdf");renderPDF.drawToFile(d,str(pdf))
    doc=pdfium.PdfDocument(str(pdf));page=doc[0];bm=page.render(scale=1.6);bm.to_pil().save(OUT/(name+".png"));bm.close();page.close();doc.close()
def main():
    OUT.mkdir(exist_ok=True);data=json.loads(CFG.read_text(encoding="utf-8"));c=data["parameters"];reports={}
    for s in data["scenarios"]:
        tr=simulate(s,c);chart(s,c,tr)
        with (OUT/(s["id"]+".csv")).open("w",encoding="utf-8-sig",newline="") as f:
            w=csv.DictWriter(f,fieldnames=list(tr[0]));w.writeheader()
            w.writerows({k:json.dumps(v,ensure_ascii=False) if isinstance(v,(list,dict)) else v for k,v in r.items()} for r in tr)
        reports[s["id"]]=dict(switches=[dict(t=r["t"],to=r["active"],source=r["source_for_review"]) for r in tr if r["switch"]],
            rejected=sum(r["x"] is not None and r["route"] is None for r in tr),
            removed=sum(len(r["removed"]) for r in tr),last_counts=[tr[-1]["nA"],tr[-1]["nB"]],
            median_input_error=median(abs(r["x"]-r["truth"]) for r in tr if r["x"] is not None),
            median_output_error=median(abs(r["output"]-r["truth"]) for r in tr if r["output"] is not None))
    result=dict(kind="optimizer_output_surrogate",production_kernel_executed=False,physical_optimizer_executed=False,
        config_sha256=hashlib.sha256(CFG.read_bytes()).hexdigest(),source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        plot_helper_sha256=hashlib.sha256(Path(__file__).with_name("filter2win_memory_experiments.py").read_bytes()).hexdigest(),scenarios=reports)
    (OUT/"observations.json").write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding="utf-8")
    frames=[Image.open(OUT/(s["id"]+".png")).convert("RGB") for s in data["scenarios"]]
    board=Image.new("RGB",(2000,780*math.ceil(len(frames)/2)),"white")
    for i,frame in enumerate(frames):board.paste(frame.resize((1000,780)),((i%2)*1000,(i//2)*780))
    board.save(OUT/"overview.png")
    print(json.dumps(reports,ensure_ascii=False))
if __name__=="__main__":main()
