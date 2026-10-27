"""Read local recorder JSONL without loading it all into RAM."""
import json,math,sys,collections
from pathlib import Path

def analyze(path):
    kinds=collections.Counter();states=collections.Counter();animations=collections.Counter();forces=collections.Counter()
    bad=duplicates=frames=0;last_seq=0;first_t=None;last_t=0;gap_count=0;by_state=collections.defaultdict(lambda:[0,0.0,0.0]);gaps=[]
    actions=collections.Counter();npc_damage=0;damage_hits=0;stalls=0;window_count=0;window_distance=0;window_time=0
    remotes=collections.Counter();client_calls=collections.Counter();pending={};rpc_errors=0;pending_evicted=0;scope={};coverage={};timings={}
    def timing(name,value):
        if not isinstance(value,(int,float)):return
        item=timings.setdefault(name,{'count':0,'total':0.,'max':0.})
        item['count']+=1;item['total']+=value;item['max']=max(item['max'],value)
    def bounded_count(counter,key):
        counter[key if key in counter or len(counter)<256 else '<other>']+=1
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
            kind=row.get('kind')
            if kind=='session_start':scope=row.get('capture',{})
            if kind=='capture_coverage':coverage=row.get('outbound',{})
            if kind=='outbound_call':
                bounded_count(remotes,row.get('method','?')+' '+row.get('object',{}).get('path','?'))
                if row.get('method')=='InvokeServer':
                    if len(pending)>=2048:pending.pop(next(iter(pending)));pending_evicted+=1
                    pending[row.get('callId')]=t
            if kind=='outbound_result':
                pending.pop(row.get('callId'),None);rpc_errors+=row.get('ok')is False
                timing('invokeDuration',row.get('duration'))
            if kind=='client_action':bounded_count(client_calls,row.get('method','?'))
            if kind=='control_recovery':
                timing('control_'+row.get('phase','?'),row.get('delay',row.get('observedBlockedDuration')))
            if kind=='marker_removed' and 'stun' in row.get('object',{}).get('name','').lower():timing('stunMarkerLifetime',row.get('lifetime'))
            if kind=='tool_action':actions[row.get('action','unknown')]+=1
            if kind=='npc_health' and row.get('delta',0)<0:npc_damage+=1
            if kind=='damage_episode' and row.get('phase')=='hit':damage_hits+=1
            if kind=='motion_window':
                window_count+=1;stalls+=bool(row.get('stalled'));duration=row.get('duration',0)
                window_time+=duration;window_distance+=duration*row.get('horizontalSpeed',0)
            if row.get("kind")=="frame":
                frames+=1;state=row.get("state","unknown");states[state]+=1
                vector=row.get("measured",[0,0,0]);speed=math.hypot(vector[0],vector[2]);up=abs(vector[1])
                group=by_state[state];group[0]+=1;group[1]+=speed;group[2]=max(group[2],speed)
            if row.get("kind")=="detail":
                for a in row.get("animations",[]):animations[a.get("id","unknown")]+=1
                for a in row.get("forces",[]):forces[a.get("class","unknown")]+=1
    manifest=Path(path).with_suffix('.manifest.json')
    if manifest.is_file()and manifest.stat().st_size<262144:
        try:coverage=json.loads(manifest.read_text(encoding='utf-8')).get('counters',{}).get('outbound',coverage)
        except (ValueError,UnicodeError):pass
    diagnostics={'captureScope':scope,'coverage':coverage,'outboundMethods':dict(remotes),'clientActions':dict(client_calls),'invokeErrors':rpc_errors,'pendingInvokeResults':len(pending),'pendingTrackingEvicted':pending_evicted,'timings':{k:{'count':v['count'],'mean':round(v['total']/v['count'],6),'max':round(v['max'],6)}for k,v in timings.items()}}
    return {"path":str(path),"durationSeconds":round(last_t-(first_t or 0),2),"frames":frames,"kinds":dict(kinds),"states":dict(states),"toolActions":dict(actions),"npcHpLossEvents":npc_damage,"playerDamageEpisodes":damage_hits,"motionWindows":window_count,"stalledWindows":stalls,"windowMeanHorizontal":round(window_distance/window_time,3)if window_time else None,"speedByState":{k:{"samples":v[0],"meanHorizontal":round(v[1]/v[0],3),"maxHorizontal":round(v[2],3)}for k,v in by_state.items()},"topAnimations":animations.most_common(20),"forces":dict(forces),"malformedLines":bad,"duplicateOrOutOfOrderLines":duplicates,"sequenceGapCount":gap_count,"firstSequenceGaps":gaps[:20],"diagnostics":diagnostics,"note":"Observed client state only; a completed InvokeServer is not proof of accepted damage, HP loss is not player attribution; this does not recover source or prove anti-cheat safety."}

if __name__=="__main__":
    print(json.dumps(analyze(sys.argv[1]),ensure_ascii=False,indent=2))
