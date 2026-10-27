--!nocheck
-- Standalone observation recorder. Owned diagnostic tap; never changes gameplay arguments.
local env=getgenv();local previous=env.__StandaloneCoordinateRecorder
if previous and previous.Cleanup then previous:Cleanup()end
local state={alive=true,connections={}};env.__StandaloneCoordinateRecorder=state
local recorder=(function()
-- Passive owner-local survey data; no gameplay writes or code capture.
local p=game:GetService("Players").LocalPlayer
local H=game:GetService("HttpService")
local Run=game:GetService("RunService")
local Input=game:GetService("UserInputService")
local Storage=game:GetService("ReplicatedStorage")
local R={alive=true,status="Ready",folder="CoordinateRecorder/records/"..p.UserId,
 maxQueueBytes=8*1024*1024,maxQueueRows=5000,connections={},characterConnections={},
 queue={},queuedBytes=0,seq=0,rows=0,samples=0,dropped=0,writeErrors=0,encodeErrors=0}
local keyNames={"W","A","S","D","Space","LeftShift","RightShift","LeftControl","RightControl","Q","E"}
local objectIds=setmetatable({},{__mode="k"});local objectSerial=0
local function number(v)return type(v)=="number"and v==v and math.abs(v)<1e100 and v or 0 end
local function vec(v)return {number(v.X),number(v.Y),number(v.Z)}end
local function frame(v)local a={v:GetComponents()};for i,x in ipairs(a)do a[i]=number(x)end;return a end
local function read(object,name)local ok,value=pcall(function()return object[name]end);if ok then return value end;return nil end
local function value(v)
 local t=typeof(v)
 if t=="number"then return number(v)elseif t=="boolean"then return v
 elseif t=="Vector3"then return vec(v)elseif t=="Vector2"then return {v.X,v.Y}
 elseif t=="CFrame"then return frame(v)elseif t=="EnumItem"then return tostring(v)end
end
local function ref(object)
 if not object then return nil end
 if not objectIds[object]then objectSerial+=1;objectIds[object]=objectSerial end
 local ok,path=pcall(function()return object:GetFullName()end)
 return {id=objectIds[object],name=object.Name,class=object.ClassName,path=ok and path:sub(1,200)or nil}
end
local function disconnect(list)for _,c in ipairs(list)do pcall(function()c:Disconnect()end)end;table.clear(list)end
local diagnosticMethods={FireServer=true,InvokeServer=true,Destroy=true,Remove=true,SetAttribute=true,ChangeState=true,SetStateEnabled=true,
 Move=true,MoveTo=true,LoadAnimation=true,Play=true,Stop=true,AdjustWeight=true,AdjustSpeed=true}
local remoteMethods={FireServer=true,InvokeServer=true}
local secretFields={key=true,token=true,password=true,secret=true,authorization=true,license=true,script_key=true,lp_key=true,webhook=true,url=true}
local function packedValues(args)
 local budget={entries=0,truncated=0};local seen={}
 local function pack(v,depth,key)
  if type(key)=="string"and(secretFields[key:lower()]or key:lower():find("token",1,true)or key:lower():find("password",1,true))then return {redacted=true}end
  local t=typeof(v)
  if t=="nil"then return {type="nil"}end
  if t=="number"and(v~=v or math.abs(v)>=1e100)then return {type="number",nonfinite=tostring(v)}end
  if t=="string"then
   if #v<=64 and v:match("^[%a_][%w_ %.%-]*$")and not(#v>24 and not v:find(" ",1,true))then return v end
   return {type="string",length=#v,redacted=true}
  elseif t=="Instance"then return {type=t,object=ref(v)}
  elseif t=="table"then
   if depth<=0 or seen[v]then budget.truncated+=1;return {type="table",truncated=true}end
   seen[v]=true;local out={type="table",entries={}}
   for k,x in pairs(v)do
    budget.entries+=1;if budget.entries>96 then budget.truncated+=1;break end
    local safeKey=type(k)=="number"or type(k)=="string"and #k<=64
    if safeKey then out.entries[#out.entries+1]={key=pack(k,0),value=pack(x,depth-1,k)}else budget.truncated+=1 end
   end
   return out
  else local x=value(v);if x~=nil then return x end;return {type=t}end
 end
 local out={n=args.n,values={}}
 for i=1,math.min(args.n,24)do out.values[i]=pack(args[i],4)end
 if args.n>24 then budget.truncated+=args.n-24 end
 out.truncated=budget.truncated;return out
end
function R:WantsCall(object,method)
 if not diagnosticMethods[method]or typeof(object)~="Instance"then return false end
 if remoteMethods[method]then return object:IsA("BaseRemoteEvent")or object:IsA("RemoteFunction")end
 if object==self.character or object==self.humanoid or object==self.root or object==self.animator then return true end
 if object:IsA("AnimationTrack")then return self.trackWatches and self.trackWatches[object]~=nil end
 return (method=="Destroy"or method=="Remove"or method=="SetAttribute")and self.markerTimes and self.markerTimes[object]~=nil
end
function R:CaptureCall(object,method,args,executor,caller)
 local stats=self.outbound;local now=os.clock()
 if now-(stats.window or 0)>=1 then stats.window=now;stats.windowCount=0 end
 stats.candidates+=1;stats.windowCount=(stats.windowCount or 0)+1
 if stats.windowCount>1000 then stats.rateLimited+=1;return nil end
 local name=object.Name:lower()
 local sensitive=remoteMethods[method]and(name:find("key",1,true)or name:find("auth",1,true)or name:find("token",1,true)or name:find("license",1,true))
 if method=="SetAttribute"and type(args[1])=="string"then sensitive=secretFields[args[1]:lower()]end
 local started=now;local payload=sensitive and{redacted=true,n=args.n}or packedValues(args);stats.truncated+=payload.truncated or 0
 stats.callSeq+=1;local id=stats.callSeq
 self:Emit(remoteMethods[method]and"outbound_call"or"client_action",{callId=id,object=ref(object),method=method,executor=executor,caller=caller and ref(caller),arguments=payload})
 stats.recorded+=1;if remoteMethods[method]then stats.remoteRecorded+=1 else stats.clientActions+=1 end;stats.maxCaptureMs=math.max(stats.maxCaptureMs,(os.clock()-started)*1000)
 return id,sensitive~=nil and sensitive~=false
end
function R:InstallObservation()
 self.outbound={requested=env.CoordinateRecorderOutbound~=false,directRequested=env.CoordinateRecorderDirectRemotes~=false,status="unsupported",seen=0,directSeen=0,candidates=0,recorded=0,remoteRecorded=0,clientActions=0,callSeq=0,errors=0,rateLimited=0,truncated=0,maxCaptureMs=0,direct={RemoteEvent="not_found",UnreliableRemoteEvent="not_found",RemoteFunction="not_found"}}
 local stats=self.outbound
 if not stats.requested then stats.status="disabled";return end
 if type(hookmetamethod)~="function"or type(newcclosure)~="function"or type(getnamecallmethod)~="function"or type(setnamecallmethod)~="function"or type(getrawmetatable)~="function"then return end
 local existing=env.__CoordinateRecorderDiagnosticTap
 if existing and existing.version~=3 then stats.status="restart_required";return end
 local tap=existing or{version=3,installed=false,busy=setmetatable({},{__mode="k"}),forwarding=setmetatable({},{__mode="k"}),methodWrappers={},wrapperCount=0}
 tap.owner=self;self.tap=tap;env.__CoordinateRecorderDiagnosticTap=tap
 local function forward(original,object,method,namecall,...)
  if namecall then setnamecallmethod(method)end
  return original(object,...)
 end
 local function dispatch(original,object,method,namecall,...)
  local owner=tap.owner
  if not owner or not owner.current then return forward(original,object,method,namecall,...)end
  local s=owner.outbound
  if not diagnosticMethods[method]then return forward(original,object,method,namecall,...)end
  local thread=coroutine.running();if tap.busy[thread]or tap.forwarding[thread]then return forward(original,object,method,namecall,...)end
  tap.busy[thread]=true
  local session=owner.current;local callId;local sensitive;local caller;local executor;local args=table.pack(...)
  local ok=pcall(function()
   if not owner:WantsCall(object,method)then return end
   if type(checkcaller)=="function"then executor=checkcaller()end
   if type(getcallingscript)=="function"then local success,v=pcall(getcallingscript);if success then caller=v end end
   callId,sensitive=owner:CaptureCall(object,method,args,executor,caller)
  end)
  tap.busy[thread]=nil;if not ok then s.errors+=1 end
  if not callId then return forward(original,object,method,namecall,...)end
  local began=os.clock();tap.forwarding[thread]=true
  local results=table.pack(pcall(forward,original,object,method,namecall,...));tap.forwarding[thread]=nil
  if owner.current==session then
   tap.busy[thread]=true
   local success=pcall(function()
    if method=="InvokeServer"or not results[1]then
     local response={n=results.n-1};for i=2,results.n do response[i-1]=results[i]end
     local payload=sensitive and{redacted=true,n=response.n}or packedValues(response);s.truncated+=payload.truncated or 0
     owner:Emit(remoteMethods[method]and"outbound_result"or"client_action_result",{callId=callId,ok=results[1],duration=os.clock()-began,result=payload})
    elseif method=="LoadAnimation"and typeof(results[2])=="Instance"and results[2]:IsA("AnimationTrack")then owner:WatchAnimation(results[2],false)end
   end)
   tap.busy[thread]=nil;if not success then s.errors+=1 end
  end
  if not results[1]then error(results[2],0)end
  return table.unpack(results,2,results.n)
 end
 tap.dispatch=dispatch
 if not tap.installed then
  local original
  local hook=newcclosure(function(object,...)
   local owner=tap.owner;if not owner or not owner.current then return original(object,...)end
   owner.outbound.seen+=1
   local method=getnamecallmethod();if not diagnosticMethods[method]then return original(object,...)end
   return tap.dispatch(original,object,method,true,...)
  end)
  local ok,result=pcall(function()return hookmetamethod(game,"__namecall",hook)end)
  if not ok then stats.status="install_failed";stats.errors+=1;return end
  original=result;tap.original=original;tap.hook=hook;tap.installed=true
 end
 stats.status="installed"
 if stats.directRequested and not tap.indexInstalled then
  local originalIndex
  local hook=newcclosure(function(object,key)
   local result=originalIndex(object,key);local owner=tap.owner
   if not owner or not owner.current or not owner.outbound.directRequested or not remoteMethods[key]or type(result)~="function"then return result end
   local class=originalIndex(object,"ClassName")
   if class~="RemoteEvent"and class~="RemoteFunction"and class~="UnreliableRemoteEvent"then return result end
   local wrapper=tap.methodWrappers[result]
   if wrapper then return wrapper end
   if tap.wrapperCount>=16 then owner.outbound.direct[class]="wrapper_limit";return result end
   wrapper=newcclosure(function(remote,...)
    local r=tap.owner;if not r or not r.current or not r.outbound.directRequested then return result(remote,...)end
    r.outbound.directSeen+=1;r.outbound.direct[class]="observed"
    return tap.dispatch(result,remote,key,false,...)
   end)
   tap.wrapperCount+=1;tap.methodWrappers[result]=wrapper;return wrapper
  end)
  local ok,mt=pcall(getrawmetatable,game)
  if ok and mt and type(mt.__index)=="function"then
   local success,result=pcall(hookmetamethod,game,"__index",hook)
   if success then originalIndex=result;tap.indexOriginal=result;tap.indexHook=hook;tap.indexInstalled=true else stats.errors+=1 end
  end
 end
end
function R:ObserveDirectRemote(remote)
 local tap=self.tap;if not tap or not self.outbound.requested then return end
 local class=remote.ClassName;local method=class=="RemoteFunction"and"InvokeServer"or"FireServer"
 if class~="RemoteFunction"and class~="RemoteEvent"and class~="UnreliableRemoteEvent"then return end
 local stats=self.outbound
 if not stats.directRequested then stats.direct[class]="disabled";return end
 if not tap.indexInstalled then stats.direct[class]="unsupported";return end
 if stats.direct[class]~="observed"then stats.direct[class]="future_lookups"end
end
function R:CheckObservation()
 local stats=self.outbound;if not stats or not self.tap then return end
 local ok,mt=pcall(getrawmetatable,game);local progressed=stats.seen>(self.lastTapSeen or 0);self.lastTapSeen=stats.seen
 local status=ok and mt and mt.__namecall==self.tap.hook and"installed"or(progressed and"observing_chain"or"chain_unverified")
 if stats.status~=status then stats.status=status;self:Emit("capture_coverage",{outbound=stats})end
end
function R:DetachObservation()
 local tap=self.tap;if not tap or tap.owner~=self then return end
 if self.outbound then self.outbound.statusBeforeStop=self.outbound.status;self.outbound.directBeforeStop=table.clone(self.outbound.direct)end
 tap.owner=nil;local ok,mt=pcall(getrawmetatable,game)
 -- Existing proxies become pass-throughs. Never replace shared native C functions.
 if ok and mt and mt.__index==tap.indexHook and tap.indexInstalled then
  if pcall(hookmetamethod,game,"__index",tap.indexOriginal)then tap.indexInstalled=false end
 end
 if self.outbound then for class in pairs(self.outbound.direct)do self.outbound.direct[class]="detached"end end
 if ok and mt and mt.__namecall==tap.hook then
  local restored=pcall(hookmetamethod,game,"__namecall",tap.original)
  if restored then tap.installed=false;if self.outbound then self.outbound.status="restored"end end
 elseif self.outbound then self.outbound.status="detached_passthrough"end
 self.tap=nil
end
function R:Connect(signal,fn,character)
 local c=signal:Connect(function(...)local ok=pcall(fn,...);if not ok then self.callbackErrors=(self.callbackErrors or 0)+1 end end)
 table.insert(character and self.characterConnections or self.connections,c);return c
end
function R:Pose()
 local c=p.Character;local root=c and c:FindFirstChild("HumanoidRootPart")
 if not root then return nil end
 return {position=vec(root.Position),cframe=frame(root.CFrame),time=os.time()}
end
function R:Coordinates()
 local a=assert(self:Pose(),"Character position unavailable").position
 return string.format("CFrame.new(%.5f, %.5f, %.5f)",a[1],a[2],a[3])
end
function R:New(kind,title,description)
 title=title or "";description=description or ""
 assert(type(title)=="string"and #title<=256,"Name must be at most 256 bytes")
 assert(type(description)=="string"and #description<=4096,"Description must be at most 4096 bytes")
 return {schema=2,id=H:GenerateGUID(false),kind=kind,title=title~=""and title or(kind=="route"and"Wide session"or"Point"),description=description,
 userId=p.UserId,placeId=game.PlaceId,universeId=game.GameId,jobId=game.JobId,createdAt=os.time(),points={},markers={}}
end
function R:EnsureFolder()
 for _,name in ipairs({"CoordinateRecorder","CoordinateRecorder/records",self.folder})do if not isfolder(name)then makefolder(name)end end
end
function R:Save(data)
 self:EnsureFolder()
 local path=self.folder.."/"..data.id..(data.kind=="route"and".manifest.json"or".json")
 if data.kind=="route"then
  data.counters={samples=self.samples,rowsWritten=self.rows,sequence=self.seq,dropped=self.dropped,writeErrors=self.writeErrors,
   encodeErrors=self.encodeErrors,appendVerified=self.appendVerified==true,callbackErrors=self.callbackErrors or 0,uiErrors=self.uiErrors or 0,pendingRows=#self.queue,pendingBytes=self.queuedBytes,outbound=self.outbound,trackWatchLimited=self.trackWatchLimited or 0,forceEventLimited=self.forceEventLimited or 0}
 end
 self.last=data;self.lastPath=data.dataPath or path
 writefile(path,H:JSONEncode(data));return self.lastPath
end
function R:Emit(kind,data)
 if not self.current then return end
 self.seq+=1;data=data or {};data.kind=kind;data.seq=self.seq;data.t=number(os.clock()-self.started);data.epoch=self.epoch or 0
 local ok,line=pcall(function()return H:JSONEncode(data).."\n"end)
 if not ok or #line>262144 then self.encodeErrors+=1;self.dropped+=1;return end
 self.queue[#self.queue+1]=line;self.queuedBytes+=#line
 local remove=0
 while #self.queue-remove>self.maxQueueRows or self.queuedBytes>self.maxQueueBytes do remove+=1;self.queuedBytes-=#self.queue[remove];self.dropped+=1 end
 if remove>0 then local kept={};for i=remove+1,#self.queue do kept[#kept+1]=self.queue[i]end;self.queue=kept end
end
function R:Flush()
 if self.flushing or not self.current and not self.finishing then return false end
 if #self.queue==0 then return true end
 self.flushing=true
 local batch=self.queue;self.queue={};self.queuedBytes=0
 local data=self.current or self.finishing
 local text=table.concat(batch)
 local ok=pcall(function()
  -- Real currently accepts small appends but silently discards 64KiB+ payloads.
  local first=1
  while first<=#text do
   local last=math.min(first+8191,#text)
   -- Keep a UTF-8 codepoint together if the executor transports strings as text.
   if last<#text then while last>=first do local byte=string.byte(text,last+1);if not byte or byte<128 or byte>=192 then break end;last-=1 end end
   assert(last>=first,"Invalid append boundary")
   appendfile(data.dataPath,text:sub(first,last));first=last+1
  end
  if not self.appendVerified then
   assert(type(readfile)=="function","Readback verification requires readfile")
   local actual=readfile(data.dataPath)
   assert(#actual>=#text and actual:sub(-#text)==text,"Append readback failed")
   self.appendVerified=true
  end
 end)
 if ok then self.rows+=#batch else
  self.writeErrors+=1
  local merged={};local bytes=0
  for _,line in ipairs(batch)do merged[#merged+1]=line;bytes+=#line end
  for _,line in ipairs(self.queue)do merged[#merged+1]=line;bytes+=#line end
  self.queue=merged;self.queuedBytes=bytes
  local remove=0
  while #self.queue-remove>self.maxQueueRows or self.queuedBytes>self.maxQueueBytes do remove+=1;self.queuedBytes-=#self.queue[remove];self.dropped+=1 end
  if remove>0 then local kept={};for i=remove+1,#self.queue do kept[#kept+1]=self.queue[i]end;self.queue=kept end
 end
 self.flushing=false;return ok
end
function R:Snapshot(title,description)
 local point=assert(self:Pose(),"Character position unavailable");local data=self:New("point",title,description);data.points[1]=point
 local path=self:Save(data)
 if self.current then
  local marker={title=data.title,description=data.description,point=point,elapsed=os.clock()-self.started}
  self.current.markers[#self.current.markers+1]=marker
  if #self.current.markers>128 then table.remove(self.current.markers,1)end
  self:Emit("marker",marker);self:Save(self.current)
 end
 return path
end
local forceProperties={"Enabled","Active","Position","CFrame","Velocity","AngularVelocity","VectorVelocity","PlaneVelocity","PrimaryTangentAxis","SecondaryTangentAxis","LineDirection","LineVelocity","Force","Torque","MaxForce","MaxAxesForce","ForceLimitMode","ForceRelativeTo","MaxTorque","MaxVelocity","MaxAngularVelocity","Responsiveness","P","D","RelativeTo","VelocityConstraintMode","ForceLimitsEnabled","RigidityEnabled","Mode","ApplyAtCenterOfMass"}
local function isForce(o)return o:IsA("BodyMover")or o:IsA("Constraint")end
function R:Force(o)
 local data=ref(o);data.properties={}
 for _,name in ipairs(forceProperties)do local v=value(read(o,name));if v~=nil then data.properties[name]=v end end
 data.attachments={}
 for _,name in ipairs({"Attachment0","Attachment1"})do
  local a=read(o,name)
  if a then data.attachments[name]={object=ref(a),position=value(read(a,"Position")),worldPosition=value(read(a,"WorldPosition")),worldCFrame=value(read(a,"WorldCFrame"))}end
 end
 return data
end
function R:ClearForceWatches()
 for _,connections in pairs(self.forceWatches or{})do disconnect(connections)end;self.forceWatches={}
end
function R:WatchForce(o)
 if self.forceWatches[o]or not(o:IsA("BodyMover")or o:IsA("LinearVelocity")or o:IsA("AlignPosition")or o:IsA("AlignOrientation")or o:IsA("VectorForce"))then return end
 local count=0;for _ in pairs(self.forceWatches)do count+=1 end;if count>=32 then return end
 local connections={};self.forceWatches[o]=connections
 for _,name in ipairs({"Enabled","MaxForce","MaxAxesForce","RigidityEnabled","Position","Velocity","PlaneVelocity","CFrame"})do
  if read(o,name)~=nil then
   local ok,signal=pcall(function()return o:GetPropertyChangedSignal(name)end)
   if ok then connections[#connections+1]=signal:Connect(function()
    local now=os.clock();if now-(self.forceEventWindow or 0)>=1 then self.forceEventWindow=now;self.forceEventCount=0 end
    self.forceEventCount=(self.forceEventCount or 0)+1
    if self.forceEventCount>300 then self.forceEventLimited=(self.forceEventLimited or 0)+1;return end
    self:Emit("force_property",{object=ref(o),property=name,value=value(read(o,name))})
   end)end
  end
 end
end
function R:WatchTool(tool)
 if not tool:IsA("Tool")or self.toolSeen[tool]then return end
 if self.toolWatchCount>=64 then return end;self.toolWatchCount+=1
 self.toolSeen[tool]=true
 for _,name in ipairs({"Activated","Deactivated","Equipped","Unequipped"})do
  local signal=read(tool,name)
  if signal then self:Connect(signal,function()self:Emit("tool_action",{tool=ref(tool),action=name,enabled=read(tool,"Enabled"),requiresHandle=read(tool,"RequiresHandle")})end,true)end
 end
end
function R:WatchNpc(n)
 if self.npcWatches[n.model]then return end
 local count=0;for _ in pairs(self.npcWatches)do count+=1 end;if count>=12 then return end
 local entry={connections={},hp=n.h.Health};self.npcWatches[n.model]=entry
 local function emit(kind,data)if self.current then data.object=ref(n.model);self:Emit(kind,data)end end
 entry.connections[#entry.connections+1]=n.h.HealthChanged:Connect(function(hp)
  local old=entry.hp;entry.hp=hp;local root=self.character and self.character:FindFirstChild("HumanoidRootPart");local head=n.model:FindFirstChild("Head")
  emit("npc_health",{health=number(hp),previous=number(old),delta=number(hp-old),p=vec(n.root.Position),cf=frame(n.root.CFrame),localRoot=root and frame(root.CFrame),relative=root and vec(n.root.Position-root.Position),distance=root and(n.root.Position-root.Position).Magnitude,head=head and{p=vec(head.Position),size=vec(head.Size)},state=n.h:GetState().Name,npcId=n.model:GetAttribute("NPCID"),note="HP change; attribution to player not established"})
 end)
 entry.connections[#entry.connections+1]=n.h.StateChanged:Connect(function(a,b)emit("npc_state",{from=a.Name,to=b.Name,p=vec(n.root.Position)})end)
end
function R:ClearNpcs()
 for _,entry in pairs(self.npcWatches or{})do disconnect(entry.connections)end;self.npcWatches={}
end
local function movementName(name)return name:lower():find("climb")or name:lower():find("vault")or name:lower():find("stun")or name:lower():find("ragdoll")or name:lower():find("dazed")or name:lower():find("disable")or name:lower():find("knock")or name:lower():find("sprint")or name:lower():find("jump")or name:lower():find("swim")or name:lower():find("speed")end
function R:ClearTracks()
 for _,entry in pairs(self.trackWatches or{})do disconnect(entry.connections)end;self.trackWatches={}
end
function R:WatchAnimation(track,started)
 local animation=read(track,"Animation")
 if started then self:Emit("animation_started",{object=ref(track),id=animation and animation.AnimationId,name=track.Name,priority=tostring(track.Priority),speed=track.Speed,weight=track.WeightCurrent})end
 if self.trackWatches[track]then return end
 local count=0;for _ in pairs(self.trackWatches)do count+=1 end
 if count>=64 then self.trackWatchLimited=(self.trackWatchLimited or 0)+1;return end
 local entry={connections={}};self.trackWatches[track]=entry
 for _,name in ipairs({"Stopped","Ended","DidLoop"})do
  local signal=read(track,name)
  if signal then entry.connections[#entry.connections+1]=signal:Connect(function()
   self:Emit("animation_lifecycle",{object=ref(track),event=name,id=animation and animation.AnimationId,position=track.TimePosition,speed=track.Speed,weight=track.WeightCurrent,targetWeight=track.WeightTarget,playing=track.IsPlaying})
   if name=="Stopped"then entry.stoppedAt=os.clock()elseif name=="Ended"then disconnect(entry.connections);self.trackWatches[track]=nil end
  end)end
 end
end
function R:ControlFrame(h,root)
 local reasons={};local c=self.character
 for _,name in ipairs({"Stun","Dazed","ragdoll","Ragdoll","Disable"})do if c:FindFirstChild(name)then reasons[#reasons+1]=name end end
 if h.WalkSpeed<=0 then reasons[#reasons+1]="zero_speed"end
 if h.PlatformStand then reasons[#reasons+1]="PlatformStand"end;if h.Sit then reasons[#reasons+1]="Sit"end
 local key=table.concat(reasons,",");local now=os.clock();local blocked=#reasons>0
 if key~=self.controlKey then
  self:Emit("control_transition",{blocked=blocked,reasons=reasons,walkSpeed=h.WalkSpeed,health=h.Health,state=h:GetState().Name,damageEpisode=self.injury and self.injury.id})
  if blocked and not self.controlBlockedAt then
   self.controlBlockedAt=now;self.controlSerial=(self.controlSerial or 0)+1
   if self.recovery then self:Emit("control_recovery",{id=self.recovery.id,phase="interrupted"});self.recovery=nil end
  elseif not blocked and self.controlBlockedAt then
   self.recovery={id=self.controlSerial,released=now};self:Emit("control_recovery",{id=self.controlSerial,phase="released",observedBlockedDuration=now-self.controlBlockedAt});self.controlBlockedAt=nil
  end
  self.controlKey=key
 end
 if self.recovery and not blocked then
  local pending=self.recovery
  if h.MoveDirection.Magnitude>.1 and not pending.intent then pending.intent=true;self:Emit("control_recovery",{id=pending.id,phase="direction_intent",delay=now-pending.released})end
  local velocity=root.AssemblyLinearVelocity
  if Vector3.new(velocity.X,0,velocity.Z).Magnitude>1 then self:Emit("control_recovery",{id=pending.id,phase="horizontal_motion",delay=now-pending.released,note="Observed motion; may include external impulses"});self.recovery=nil
  elseif now-pending.released>10 then self:Emit("control_recovery",{id=pending.id,phase="no_motion_10s"});self.recovery=nil end
 end
end
function R:Bind(character)
 disconnect(self.characterConnections);self:ClearNpcs();self:ClearTracks();self:ClearForceWatches();self.markerTimes=setmetatable({},{__mode="k"});self.controlKey=nil;self.controlBlockedAt=nil;self.recovery=nil
 self.toolSeen=setmetatable({},{__mode="k"});self.toolWatchCount=0;self.motionWindow=nil;self.injury=nil;self.previousGoal=nil
 self.character=character;self.epoch=(self.epoch or 0)+1;self.lastFrame=nil;self.forces={}
 self:Emit("character",{available=character~=nil})
 if not character then return end
 for _,o in ipairs(character:GetDescendants())do if isForce(o)then self.forces[o]=true;self:WatchForce(o)elseif movementName(o.Name)then self.markerTimes[o]=os.clock()end end
 local function attributes(object)
  local signal=read(object,"AttributeChanged")
  if signal then self:Connect(signal,function(name)if movementName(name)then self:Emit("attribute_changed",{object=ref(object),attribute=name,value=value(object:GetAttribute(name))})end end,true)end
 end
 attributes(character)
 self:Connect(character.DescendantAdded,function(o)
  self:WatchTool(o)
  if isForce(o)then self.forces[o]=true;self:WatchForce(o);self:Emit("force_added",self:Force(o))
  elseif movementName(o.Name)then self.markerTimes[o]=os.clock();self:Emit("marker_added",{object=ref(o),value=value(read(o,"Value")),damageEpisode=self.injury and self.injury.id})end
 end,true)
 self:Connect(character.DescendantRemoving,function(o)
  if self.forces[o]then self:Emit("force_removed",{object=ref(o)});self.forces[o]=nil;if self.forceWatches[o]then disconnect(self.forceWatches[o]);self.forceWatches[o]=nil end
  elseif movementName(o.Name)then self:Emit("marker_removed",{object=ref(o),lifetime=self.markerTimes[o]and os.clock()-self.markerTimes[o],damageEpisode=self.injury and self.injury.id});self.markerTimes[o]=nil end
 end,true)
 local h=character:FindFirstChildOfClass("Humanoid")
 self.humanoid=h;self.root=character:FindFirstChild("HumanoidRootPart");self.animator=nil
 if self.root then attributes(self.root)end
 if h then
  attributes(h)
  self:Connect(h.StateChanged,function(a,b)self:Emit("humanoid_state",{from=a.Name,to=b.Name})end,true)
  local lastHp=h.Health
  self:Connect(h.HealthChanged,function(hp)
   self:Emit("health",{health=hp,previous=lastHp,delta=number(hp-lastHp),maxHealth=h.MaxHealth})
   if hp<lastHp then
    self.injurySerial=(self.injurySerial or 0)+1;self.injury={id=self.injurySerial,t=os.clock(),hp=hp}
    self:Emit("damage_episode",{id=self.injurySerial,phase="hit",loss=lastHp-hp,health=hp})
   end;lastHp=hp
  end,true)
  for _,name in ipairs({"WalkSpeed","JumpPower","JumpHeight","HipHeight","AutoRotate","PlatformStand","Sit","UseJumpPower"})do
   self:Connect(h:GetPropertyChangedSignal(name),function()self:Emit("humanoid_property",{property=name,value=value(read(h,name))})end,true)
  end
  local animator=h:FindFirstChildOfClass("Animator")
  if animator then self.animator=animator
   for _,track in ipairs(animator:GetPlayingAnimationTracks())do self:WatchAnimation(track,false)end
   self:Connect(animator.AnimationPlayed,function(track)self:WatchAnimation(track,true)end,true)
  end
 end
 local backpack=p:FindFirstChild("Backpack")
 if backpack then
  for _,o in ipairs(backpack:GetChildren())do self:WatchTool(o)end
  self:Connect(backpack.DescendantAdded,function(o)self:WatchTool(o)end,true)
 end
 for _,o in ipairs(character:GetChildren())do self:WatchTool(o)end
 for _,o in ipairs(character:GetDescendants())do
  if o:IsA("BasePart")then
   for _,name in ipairs({"CanCollide","Anchored","CollisionGroup"})do self:Connect(o:GetPropertyChangedSignal(name),function()
    self:Emit("part_property",{object=ref(o),property=name,value=name=="CollisionGroup"and o.CollisionGroup or value(read(o,name))})
   end,true)end
  end
 end
end
function R:Frame(dt)
 local c=p.Character;if c~=self.character then self:Bind(c)end
 local root=c and c:FindFirstChild("HumanoidRootPart");local h=c and c:FindFirstChildOfClass("Humanoid")
 if not root or not h then return end
 local now=os.clock();local pos=root.Position
 self:ControlFrame(h,root)
 local elapsed=self.lastFrame and now-self.lastFrame.t or 0
 local displacement=self.lastFrame and elapsed>0 and (pos-self.lastFrame.p)/elapsed or Vector3.zero
 self:Emit("frame",{dt=number(dt or elapsed),p=vec(pos),cf=frame(root.CFrame),v=vec(root.AssemblyLinearVelocity),av=vec(root.AssemblyAngularVelocity),measured=vec(displacement),
  move=vec(h.MoveDirection),walkTo=vec(h.WalkToPoint),state=h:GetState().Name,walkSpeed=h.WalkSpeed,hip=h.HipHeight,jumpPower=h.JumpPower,jumpHeight=h.JumpHeight,
  jump=h.Jump,floor=h.FloorMaterial.Name,health=h.Health,maxHealth=h.MaxHealth,anchored=root.Anchored,collide=root.CanCollide,collisionGroup=root.CollisionGroup,
  autoRotate=h.AutoRotate,platformStand=h.PlatformStand,sit=h.Sit})
 self.lastFrame={t=now,p=pos};self.samples+=1
 local w=self.motionWindow
 if not w then self.motionWindow={t=now,p=pos,last=pos,path=0,up=0,down=0}
 else
  local delta=pos-w.last;w.path+=Vector3.new(delta.X,0,delta.Z).Magnitude;w.up+=math.max(0,delta.Y);w.down+=math.max(0,-delta.Y);w.last=pos
  if now-w.t>=.2 then
   local duration=now-w.t;local speed=w.path/duration
   self:Emit("motion_window",{duration=duration,horizontalSpeed=speed,upSpeed=w.up/duration,downSpeed=w.down/duration,move=vec(h.MoveDirection),state=h:GetState().Name,stalled=speed<1 and h.MoveDirection.Magnitude>.5,frameGap=elapsed>.1})
   self.motionWindow=nil
  end
 end
 local goal=h.WalkToPoint
 if not self.previousGoal or(goal-self.previousGoal).Magnitude>.1 then self.previousGoal=goal;self:Emit("walk_goal",{p=vec(goal)})end
 if self.injury then
  local age=now-self.injury.t
  if age>=2 then self:Emit("damage_episode",{id=self.injury.id,phase="after_2s",health=h.Health,state=h:GetState().Name,p=vec(pos),walkSpeed=h.WalkSpeed});self.injury=nil end
 end
 local point={position=vec(pos),cframe=frame(root.CFrame),time=os.time(),elapsed=now-self.started}
 if #self.current.points==0 then self.current.points[1]=point else self.current.points[2]=point end
end
function R:Medium()
 local c=self.character;local root=c and c:FindFirstChild("HumanoidRootPart");local h=c and c:FindFirstChildOfClass("Humanoid")
 if not root or not h then return end
 for track,entry in pairs(self.trackWatches)do if entry.stoppedAt and os.clock()-entry.stoppedAt>1 then disconnect(entry.connections);self.trackWatches[track]=nil end end
 local data={forces={},animations={},attributes={},keys={},combatMarkers={},tools={},focused=self.focused~=false,damageEpisode=self.injury and self.injury.id}
 for _,o in ipairs(c:GetChildren())do
  if movementName(o.Name)or o.Name:lower():find("block")or o.Name:lower():find("attack")then
   if #data.combatMarkers<32 then data.combatMarkers[#data.combatMarkers+1]={object=ref(o),value=value(read(o,"Value"))}end
  end
  if o:IsA("Tool")and #data.tools<16 then data.tools[#data.tools+1]={object=ref(o),enabled=read(o,"Enabled"),attributes={Ready=value(o:GetAttribute("Ready")),Reloaded=value(o:GetAttribute("Reloaded"))}}end
 end
 local count=0
 for o in pairs(self.forces)do
  if o.Parent then count+=1;if count<=48 then data.forces[#data.forces+1]=self:Force(o)end else self.forces[o]=nil end
 end
 data.forceCount=count
 local animator=h:FindFirstChildOfClass("Animator")
 if animator then for i,track in ipairs(animator:GetPlayingAnimationTracks())do if i<=32 then
  local animation=read(track,"Animation");data.animations[#data.animations+1]={id=animation and animation.AnimationId,name=track.Name,speed=track.Speed,weight=track.WeightCurrent,targetWeight=track.WeightTarget,position=track.TimePosition,length=track.Length,priority=tostring(track.Priority)}
 end end end
 for name,v in pairs(c:GetAttributes())do if movementName(name)then data.attributes[name]=value(v)end end
 if not Input:GetFocusedTextBox()then for _,name in ipairs(keyNames)do if Input:IsKeyDown(Enum.KeyCode[name])then data.keys[#data.keys+1]=name end end end
 local camera=workspace.CurrentCamera;if camera then data.camera=frame(camera.CFrame)end
 self:Emit("detail",data)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={c};params.RespectCanCollide=true
 local direction=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
 if direction.Magnitude<.01 then direction=Vector3.new(0,0,-1)else direction=direction.Unit end
 local move=Vector3.new(h.MoveDirection.X,0,h.MoveDirection.Z);if move.Magnitude>.01 then move=move.Unit else move=direction end
 local probes={{"floor",root.Position,Vector3.new(0,-16,0)},{"ceiling",root.Position,Vector3.new(0,16,0)},
 {"forward",root.Position,direction*12},{"low",root.Position-Vector3.new(0,1.5,0),direction*12},{"high",root.Position+Vector3.new(0,3,0),direction*12},
 {"travel",root.Position,move*12},{"landing",root.Position+move*8+Vector3.new(0,6,0),Vector3.new(0,-24,0)}}
 local geometry={}
 for _,probe in ipairs(probes)do
  local hit=workspace:Raycast(probe[2],probe[3],params)
  local row={name=probe[1],origin=vec(probe[2]),direction=vec(probe[3]),hit=hit~=nil}
  if hit then
   row.p=vec(hit.Position);row.normal=vec(hit.Normal);row.distance=hit.Distance;row.material=hit.Material.Name;row.object=ref(hit.Instance)
   if hit.Instance:IsA("BasePart")then row.size=vec(hit.Instance.Size);row.cf=frame(hit.Instance.CFrame);row.collide=hit.Instance.CanCollide end
  end
  geometry[#geometry+1]=row
 end
 self:Emit("geometry",{probes=geometry})
end
local function values(folder)
 local out={};if not folder then return out end
 for i,o in ipairs(folder:GetChildren())do if i<=32 and o:IsA("ValueBase")and not o.Name:lower():find("key")and not o.Name:lower():find("token")then
  local v=read(o,"Value");if type(v)=="string"then out[o.Name]=v:sub(1,256)else out[o.Name]=value(v)end
 end end
 return out
end
function R:Slow()
 local stats=Storage:FindFirstChild("Stats"..p.Name);local quest=stats and stats:FindFirstChild("Quest")
 local account={quest=values(quest),progress={}}
 for _,name in ipairs({"Level","Peli","Money","EXP","Experience"})do
  local child=stats and(stats:FindFirstChild(name)or(stats:FindFirstChild("Stats")and stats.Stats:FindFirstChild(name)))
  if child and type(read(child,"Value"))=="number"then account.progress[name]=child.Value end
 end
 account.tools={}
 local containers={};local backpack=p:FindFirstChild("Backpack");if backpack then containers[#containers+1]=backpack end;if self.character then containers[#containers+1]=self.character end
 for _,container in ipairs(containers)do if container then for _,o in ipairs(container:GetChildren())do
  if o:IsA("Tool")and #account.tools<64 then account.tools[#account.tools+1]={name=o.Name,equipped=container==self.character}end
 end end end
 self:Emit("game_state",account)
 local root=self.character and self.character:FindFirstChild("HumanoidRootPart");if not root then return end
 local folders={};local candidates={};local seen={}
 for _,name in ipairs({"NPCs","Enemies","Mobs"})do
  local a=workspace:FindFirstChild(name);if a then folders[#folders+1]=a end
  local env=workspace:FindFirstChild("Env");local b=env and env:FindFirstChild(name);if b then folders[#folders+1]=b end
 end
 for _,folder in ipairs(folders)do for i,model in ipairs(folder:GetChildren())do if i<=500 and not seen[model]and model:IsA("Model")then
  seen[model]=true;local h=model:FindFirstChildOfClass("Humanoid");local part=model:FindFirstChild("HumanoidRootPart")or model.PrimaryPart
  if h and part then local distance=(part.Position-root.Position).Magnitude;if distance<=180 then candidates[#candidates+1]={model=model,h=h,root=part,distance=distance}end end
 end end end
 table.sort(candidates,function(a,b)return a.distance<b.distance end)
 local targets={}
 local retained={};for i=1,math.min(12,#candidates)do retained[candidates[i].model]=true end
 for model,entry in pairs(self.npcWatches)do if not retained[model]then disconnect(entry.connections);self.npcWatches[model]=nil end end
 for i=1,math.min(12,#candidates)do local n=candidates[i];local target=n.model:FindFirstChild("Target");local targetValue=target and read(target,"Value")
  self:WatchNpc(n)
  targets[#targets+1]={object=ref(n.model),p=vec(n.root.Position),v=vec(n.root.AssemblyLinearVelocity),health=n.h.Health,maxHealth=n.h.MaxHealth,
   state=n.h:GetState().Name,distance=n.distance,targetsLocal=targetValue==p or targetValue==self.character}
 end
 self:Emit("nearby_npcs",{available=#folders>0,items=targets,totalNearby=#candidates})
end
local remoteWords={"quest","climb","vault","combat","attack","damage","fishing","fish","bait","rod","shop","craft","merchant","spawn","style","equip","weapon","shoot","reload","block","dash","geppo","swim"}
local allowedWords={Start=true,Stop=true,Climb=true,Jump=true,Cast=true,Reel=true,Catch=true,OpenShop=true,SellFish=true,Craft=true,TakeQuest=true,QuitQuest=true,Accept=true,Complete=true,Success=true,Failed=true,Equip=true,M1=true,Reload=true}
local allowedFields={Method=true,Action=true,Type=true,Count=true,Amount=true,Status=true,Success=true,Position=true}
local function argument(v,depth)
 local t=typeof(v)
 if t=="string"then return allowedWords[v]and v or{type="string",length=#v}
 elseif t=="table"then
  local out={type="table"};if depth>0 then local n=0;for k,x in pairs(v)do if type(k)=="string"and allowedFields[k]then n+=1;if n<=12 then out[k]=argument(x,depth-1)end end end end;return out
 elseif t=="Instance"then return {type="Instance",class=v.ClassName}
 else local result=value(v);if result~=nil then return result end;return {type=t}end
end
function R:ObserveRemotes()
 local folder=Storage:FindFirstChild("Events");if not folder then return end
 self.remoteSeen=self.remoteSeen or setmetatable({},{__mode="k"})
 for _,remote in ipairs(folder:GetDescendants())do
  self:ObserveDirectRemote(remote)
  if not self.remoteSeen[remote]and(remote:IsA("RemoteEvent")or remote:IsA("UnreliableRemoteEvent"))then
  local name=remote.Name:lower();local wanted=false;for _,word in ipairs(remoteWords)do if name:find(word,1,true)then wanted=true;break end end
  if wanted then
   self.remoteSeen[remote]=true
   self:Connect(remote.OnClientEvent,function(...)
    if not self.current then return end
    local args={};for i=1,math.min(select('#',...),16)do args[i]=argument(select(i,...),2)end
    self:Emit("server_event",{remote=ref(remote),argumentCount=select('#',...),arguments=args})
   end)
   self:Emit("observed_remote",{remote=ref(remote)})
  end
 end end
end
function R:Start(title,description)
 assert(self.alive and not self.current and not self.finishing,"Recording already active or still flushing")
 assert(type(appendfile)=="function","Executor appendfile support is required")
 self:EnsureFolder();local data=self:New("route",title,description)
 data.state="recording";data.format="jsonl";data.dataPath=self.folder.."/"..data.id..".jsonl"
 data.capture={frames="every Heartbeat",detailsHz=10,gameStateHz=1,geometryProbes=7,nearbyNpcLimit=12,npcHealth="event driven for nearest 12; discovery 1Hz",toolActions=true,motionWindows=.2,forceAttachments=true,inboundRemotes="filtered names; strings redacted",outboundRemotes=true,executorCallsIncluded=true,invokeResults=true,preexistingCachedCalls=false,animationLifecycle=true,controlTransitions=true,propertyWriteCaller=false,arbitraryLuaCalls=false,keyNames=keyNames,maxQueueBytes=self.maxQueueBytes,argumentLimits={depth=4,entries=96,args=24},maxDiagnosticCallsPerSecond=1000}
 writefile(data.dataPath,"")
 self.queue={};self.queuedBytes=0;self.seq=0;self.rows=0;self.samples=0;self.dropped=0;self.writeErrors=0;self.encodeErrors=0;self.callbackErrors=0
 self.appendVerified=false;self.lastTapSeen=0;self.current=data;self.started=os.clock();self.mediumAt=0;self.slowAt=0;self.remoteAt=0;self.saveAt=0;self.epoch=0
 self:InstallObservation();data.capture.outboundRemotes=self.outbound.requested;data.capture.outboundInitialStatus=self.outbound.status
 self:Emit("session_start",{placeId=game.PlaceId,universeId=game.GameId,jobId=game.JobId,createdAt=data.createdAt,capture=data.capture})
 self:Bind(p.Character);self:ObserveRemotes();self:Emit("capture_coverage",{outbound=self.outbound});self:Save(data)
 self.status="Recording (until Stop)"
 return data.dataPath
end
function R:Stop(reason)
 local data=self.current;if not data then return self.lastPath end
 self:DetachObservation()
 self:Emit("session_stop",{reason=reason or "User Stop"});data.state="stopped";data.stopReason=reason or "User Stop";data.finishedAt=os.time();data.duration=os.clock()-self.started
 self.current=nil;self.finishing=data;disconnect(self.characterConnections);self:ClearNpcs();self:ClearTracks();self:ClearForceWatches();self.character=nil;self.forces={}
 self:Flush();self:Save(data)
 if #self.queue==0 and not self.flushing then self.finishing=nil end
 self.status=#self.queue==0 and "Stopped and saved"or "Stopped; waiting for disk write"
 return self.lastPath
end
function R:UpdateNotes(title,description)
 local data=assert(self.current,"Start recording first");assert(#title<=256 and #description<=4096,"Notes too long")
 data.title=title~=""and title or data.title;data.description=description;self:Emit("notes",{title=data.title,description=description});return self:Save(data)
end
function R:Tick(dt)
 if not self.alive or not self.current then return end
 if game.JobId~=self.current.jobId then self:Stop("Game session changed");return end
 local ok=pcall(function()
  self:Frame(dt);local now=os.clock()
  if now-self.mediumAt>=.1 then self.mediumAt=now;self:Medium()end
  if now-self.slowAt>=1 then self.slowAt=now;self:Slow();self:CheckObservation()end
  if now-self.remoteAt>=5 then self.remoteAt=now;self:ObserveRemotes()end
  self.status=string.format("REC %d frames | remote %d | %s | lost %d | I/O %d",self.samples,self.outbound.remoteRecorded,self.outbound.status,self.dropped,self.writeErrors)
 end)
 if not ok then self.callbackErrors+=1;self.status="Recording; sample errors: "..self.callbackErrors end
end
function R:Unload()
 if not self.alive then return end
 pcall(function()self:Stop("Recorder unloaded")end);self.alive=false
 disconnect(self.characterConnections);disconnect(self.connections)
end
local function key(input)
 for _,name in ipairs(keyNames)do if input.KeyCode==Enum.KeyCode[name]then return name end end
end
R:Connect(Input.InputBegan,function(input,processed)
 if R.current and not Input:GetFocusedTextBox()then local name=key(input);if name then R:Emit("input",{key=name,down=true,processed=processed})end
  local kind=tostring(read(input,"UserInputType"));if kind=="Enum.UserInputType.MouseButton1"or kind=="Enum.UserInputType.MouseButton2"then R:Emit("attack_input",{button=kind,down=true,processed=processed,note="Input only; not proof of attack"})end
 end
end)
R:Connect(Input.InputEnded,function(input,processed)
 if R.current then local name=key(input);if name then R:Emit("input",{key=name,down=false,processed=processed})end end
end)
R:Connect(Input.WindowFocusReleased,function()R.focused=false;R:Emit("focus",{focused=false})end)
R:Connect(Input.WindowFocused,function()R.focused=true;R:Emit("focus",{focused=true})end)
task.spawn(function()
 local shutdownFailures=0
 while R.alive or(R.finishing and #R.queue>0)do
  task.wait(.5)
  if R.current or R.finishing then
   local flushed=R:Flush();if not R.alive and not flushed then shutdownFailures+=1 end;local data=R.current or R.finishing
   if data then local ok=pcall(function()R:Save(data)end);if not ok then R.writeErrors+=1 end end
   if R.finishing and #R.queue==0 and not R.flushing then R.finishing=nil end
   if shutdownFailures>=3 then if data then data.unflushedRows=#R.queue end;break end
  end
 end
end)
return R
end)()
state.recorder=recorder
local Input=game:GetService("UserInputService");local Run=game:GetService("RunService")
local colors={background=Color3.fromHex("#151515"),surface=Color3.fromHex("#1C1C1C"),element=Color3.fromHex("#242424"),border=Color3.fromHex("#3A3A3A"),accent=Color3.fromHex("#9B1E28"),text=Color3.fromHex("#EEEEEE"),muted=Color3.fromHex("#AAAAAA")}
local function new(class,props,parent)
 local o=Instance.new(class)
 if o:IsA("GuiBase2d")then o.AutoLocalize=false end
 if o:IsA("TextLabel")or o:IsA("TextButton")or o:IsA("TextBox")then o.Font=Enum.Font.BuilderSans;o.TextSize=14;o.TextColor3=colors.text;o.RichText=false end
 for k,v in pairs(props)do o[k]=v end
 o.Parent=parent;return o
end
local uiIdentity
if type(getthreadidentity)=="function"then local ok,id=pcall(getthreadidentity);if ok then uiIdentity=id end end
local function connect(signal,fn)
 local c=signal:Connect(function(...)
  if not state.alive then return end
  local before
  if uiIdentity and type(setthreadidentity)=="function"then
   local ok,id=pcall(getthreadidentity);if ok then before=id end
   if before~=uiIdentity then pcall(setthreadidentity,uiIdentity)end
  end
  local ok=pcall(fn,...)
  if before and before~=uiIdentity then pcall(setthreadidentity,before)end
  if not ok then recorder.uiErrors=(recorder.uiErrors or 0)+1 end
 end)
 state.connections[#state.connections+1]=c;return c
end
local function corner(o,r)new("UICorner",{CornerRadius=UDim.new(0,r)},o)end
local guiParent=gethui and gethui()or game:GetService("CoreGui")
pcall(function()
 local oldGui=guiParent:FindFirstChild("CoordinateRecorderStandalone")
 if oldGui and oldGui:GetAttribute("CoordinateRecorderOwner")=="CoordinateRecorderStandalone"then oldGui:Destroy()end
end)
local gui=new("ScreenGui",{Name="CoordinateRecorderStandalone",ResetOnSpawn=false,IgnoreGuiInset=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=80},guiParent)
gui:SetAttribute("CoordinateRecorderOwner","CoordinateRecorderStandalone")
local window=new("Frame",{Name="Window",Size=UDim2.fromOffset(800,510),AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),BackgroundColor3=colors.background,BorderSizePixel=0,Active=true},gui)
corner(window,12);new("UIStroke",{Color=colors.border,Thickness=1},window)
local bar=new("Frame",{Name="Titlebar",Size=UDim2.new(1,0,0,42),BackgroundTransparency=1,Active=true},window)
new("TextLabel",{Text="Coordinate Recorder",Font=Enum.Font.BuilderSansBold,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Position=UDim2.fromOffset(18,0),Size=UDim2.new(1,-110,1,0),Active=false},bar)
new("Frame",{Name="Divider",Position=UDim2.new(0,16,0,42),Size=UDim2.new(1,-32,0,1),BackgroundColor3=colors.border,BackgroundTransparency=.55,BorderSizePixel=0},window)
function state:Cleanup()
 if not self.alive then return end
 self.alive=false;pcall(function()recorder:Unload()end)
 for _,c in ipairs(self.connections)do pcall(function()c:Disconnect()end)end
 pcall(function()gui:Destroy()end)
 if env.__StandaloneCoordinateRecorder==self then env.__StandaloneCoordinateRecorder=nil end
end
connect(gui.Destroying,function()state:Cleanup()end)
local close=new("TextButton",{Name="Close",Text="×",TextSize=22,Size=UDim2.fromOffset(36,32),Position=UDim2.new(1,-43,0,5),BackgroundTransparency=1,AutoButtonColor=false},bar)
connect(close.Activated,function()state:Cleanup()end)
local hide=new("TextButton",{Name="Hide",Text="−",TextSize=22,Size=UDim2.fromOffset(36,32),Position=UDim2.new(1,-82,0,5),BackgroundTransparency=1,AutoButtonColor=false},bar)
connect(hide.Activated,function()window.Visible=false end)
local function section(title,left,height)
 local frame=new("Frame",{Name=title,Position=UDim2.new(left and 0 or .5,left and 16 or 8,0,60),Size=UDim2.new(.5,-24,0,height),BackgroundColor3=colors.surface,BackgroundTransparency=.5,BorderSizePixel=0},window)
 corner(frame,8);new("UIStroke",{Color=colors.border,Thickness=1,Transparency=.32},frame)
 new("TextLabel",{Text=title,Font=Enum.Font.BuilderSansBold,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Position=UDim2.fromOffset(14,0),Size=UDim2.new(1,-28,0,40)},frame)
 new("Frame",{Position=UDim2.new(0,1,0,39),Size=UDim2.new(1,-2,0,1),BackgroundColor3=colors.border,BackgroundTransparency=.58,BorderSizePixel=0},frame)
 return frame
end
local points=section("Coordinate Notes",true,326);local routes=section("Route Recording",false,366)
local function label(parent,text,y)
 return new("TextLabel",{Text=text,TextColor3=colors.muted,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Position=UDim2.fromOffset(12,y),Size=UDim2.new(1,-24,0,22)},parent)
end
local function textbox(parent,name,y,height,multiline)
 local box=new("TextBox",{Name=name,Text="",PlaceholderText=name,PlaceholderColor3=colors.muted,ClearTextOnFocus=false,MultiLine=multiline,TextWrapped=multiline,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,Position=UDim2.fromOffset(12,y),Size=UDim2.new(1,-24,0,height),BackgroundColor3=colors.element,BorderSizePixel=0,Active=true,Selectable=true,ZIndex=2},parent)
 corner(box,6);new("UIPadding",{PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10),PaddingTop=UDim.new(0,multiline and 8 or 0),PaddingBottom=UDim.new(0,multiline and 8 or 0)},box)
 return box
end
label(points,"Name",48);local title=textbox(points,"Name",74,34,false)
label(points,"Description",116);local description=textbox(points,"Description",142,94,true)
local feedback=new("TextLabel",{Name="Feedback",Text="Right Shift: show / hide   •   Drag the title bar to move",TextColor3=colors.muted,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Position=UDim2.new(0,18,1,-55),Size=UDim2.new(1,-42,0,42)},window)
local function action(fn)
 local ok,result=pcall(fn);feedback.Text=ok and tostring(result or"Done")or tostring(result);feedback.TextColor3=ok and colors.muted or Color3.fromRGB(255,140,140)
end
local function button(parent,text,y,fn,accent)
 local b=new("TextButton",{Name=text,Text=text,Position=UDim2.fromOffset(12,y),Size=UDim2.new(1,-24,0,32),BackgroundColor3=accent and colors.accent or colors.element,BorderSizePixel=0,AutoButtonColor=false},parent)
 corner(b,6)
 connect(b.Activated,function()if state.alive then action(fn)end end)
 connect(b.MouseEnter,function()b.BackgroundColor3=accent and Color3.fromHex("#B12632")or Color3.fromHex("#303030")end)
 connect(b.MouseLeave,function()b.BackgroundColor3=accent and colors.accent or colors.element end)
 return b
end
button(points,"Copy Coordinates",246,function()local value=recorder:Coordinates();setclipboard(value);return value end)
button(points,"Save Snapshot / Marker",286,function()return recorder:Snapshot(title.Text,description.Text)end)
local status=new("TextLabel",{Name="Status",Text="Ready",TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,BackgroundTransparency=1,Position=UDim2.fromOffset(12,51),Size=UDim2.new(1,-24,0,68)},routes)
button(routes,"Start Recording",126,function()recorder:Start(title.Text,description.Text);return "Full recording started; streaming to JSONL"end,true)
button(routes,"Stop and Save",166,function()return recorder:Stop()or"No active recording"end)
button(routes,"Update Recording Notes",206,function()return recorder:UpdateNotes(title.Text,description.Text)end)
button(routes,"Copy Last File Path",246,function()local path=assert(recorder.lastPath,"No saved file");setclipboard(path);return path end)
button(routes,"Copy Session Manifest",286,function()setclipboard(game:GetService("HttpService"):JSONEncode(assert(recorder.last,"No recording or snapshot")));return "JSON copied"end)
label(routes,"Every Heartbeat | streaming every 0.5s | no time limit",330)
local resize=new("TextButton",{Name="Resize",Text="◢",TextSize=18,TextColor3=colors.accent,BackgroundTransparency=1,AnchorPoint=Vector2.new(1,1),Position=UDim2.fromScale(1,1),Size=UDim2.fromOffset(24,24)},window)
local gesture
local function begin(input,kind)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then gesture={kind=kind,input=input,start=input.Position,position=window.Position,size=window.Size}end
end
connect(bar.InputBegan,function(input)begin(input,"drag")end)
connect(resize.InputBegan,function(input)begin(input,"resize")end)
connect(Input.InputChanged,function(input)
 local g=gesture;if not g then return end
 if input.UserInputType~=Enum.UserInputType.MouseMovement and input~=g.input then return end
 local delta=input.Position-g.start
 if g.kind=="drag"then window.Position=UDim2.new(g.position.X.Scale,g.position.X.Offset+delta.X,g.position.Y.Scale,g.position.Y.Offset+delta.Y)
 else local viewport=workspace.CurrentCamera.ViewportSize;window.Size=UDim2.fromOffset(math.clamp(g.size.X.Offset+delta.X,560,math.max(560,viewport.X-24)),math.clamp(g.size.Y.Offset+delta.Y,490,math.max(490,viewport.Y-24)))end
end)
connect(Input.InputEnded,function(input)if gesture and(input==gesture.input or input.UserInputType==Enum.UserInputType.MouseButton1)then gesture=nil end end)
connect(Input.InputBegan,function(input,processed)
 if input.KeyCode==Enum.KeyCode.RightShift and not processed and not Input:GetFocusedTextBox()then window.Visible=not window.Visible end
end)
local tick=0
connect(Run.Heartbeat,function(dt)
 if not state.alive then return end
 recorder:Tick(dt);tick+=dt;if tick<.25 then return end;tick=0
 local message=recorder.status
 if message:sub(1,6)=="Saved:"then message="Saved successfully"end
 status.Text=message.."\n"..recorder.folder
end)
if env.CoordinateRecorderAutoStart~=false then
 local ok,err=pcall(function()recorder:Start("Wide session","")end)
 if not ok then recorder.status="Start failed: "..tostring(err)end
end
return state
