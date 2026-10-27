"""Read local recorder JSONL without loading it all into RAM."""
import json,math,sys,collections
from pathlib import Path

def analyze(path):
    kinds=collections.Counter();states=collections.Counter();animations=collections.Counter();forces=collections.Counter()
    bad=duplicates=frames=0;last_seq=0;first_t=None;last_t=0;gap_count=0;by_state=collections.defaultdict(lambda:[0,0.0,0.0]);gaps=[]
    with Path(path).open(encoding="utf-8") as stream:
        for line in stream:
            try: row=json.loads(line)
            except (ValueError,UnicodeError): bad+=1;continue
            seq=row.get("seq",0)
            if seq<=last_seq: duplicates+=1;continue
            if last_seq and seq>last_seq+1:
                gap_count+=1
                if len(gaps)<20:gaps.append([last_seq+1,seq-1])
            last_seq=seq;kinds[row.get("kind","unknown")]+=1;t=row.get("t",0)
            if first_t is None:first_t=t
            last_t=max(last_t,t)
            if row.get("kind")=="frame":
                frames+=1;state=row.get("state","unknown");states[state]+=1
                vector=row.get("measured",[0,0,0]);speed=math.hypot(vector[0],vector[2]);up=abs(vector[1])
                group=by_state[state];group[0]+=1;group[1]+=speed;group[2]=max(group[2],speed)
            if row.get("kind")=="detail":
                for a in row.get("animations",[]):animations[a.get("id","unknown")]+=1
                for a in row.get("forces",[]):forces[a.get("class","unknown")]+=1
    return {"path":str(path),"durationSeconds":round(last_t-(first_t or 0),2),"frames":frames,"kinds":dict(kinds),"states":dict(states),"speedByState":{k:{"samples":v[0],"meanHorizontal":round(v[1]/v[0],3),"maxHorizontal":round(v[2],3)}for k,v in by_state.items()},"topAnimations":animations.most_common(20),"forces":dict(forces),"malformedLines":bad,"duplicateOrOutOfOrderLines":duplicates,"sequenceGapCount":gap_count,"firstSequenceGaps":gaps[:20],"note":"Observed client state only; this does not recover source or prove navigation/anti-cheat safety."}

if __name__=="__main__":
    print(json.dumps(analyze(sys.argv[1]),ensure_ascii=False,indent=2))
