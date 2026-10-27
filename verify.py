from pathlib import Path
import subprocess,sys,tempfile,json
root=Path(__file__).resolve().parent
runtime=sys.argv[1]
whole=(root/'main.lua').read_text(encoding='utf-8')
source=whole[whole.index('-- Passive owner-local survey'):whole.index('end)()')]
fixture=r'''local env={};local now=0;local methodName="FireServer"
local os={time=function()return 1000+math.floor(now)end,clock=function()return now end}
local function signal()
 local s={listeners={}}
 function s:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;self.listeners[#self.listeners+1]={fn,c};return c end
 function s:Fire(...)for _,item in ipairs(self.listeners)do if item[2].Connected then item[1](...)end end end
 return s
end
local vectorMT={__type="Vector3"}
local function v(x,y,z)return setmetatable({X=x,Y=y,Z=z},vectorMT)end
vectorMT.__add=function(a,b)return v(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
vectorMT.__sub=function(a,b)return v(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
vectorMT.__mul=function(a,b)return v(a.X*b,a.Y*b,a.Z*b)end
vectorMT.__div=function(a,b)return v(a.X/b,a.Y/b,a.Z/b)end
vectorMT.__index=function(a,k)if k=="Magnitude"then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z)elseif k=="Unit"then return a/math.max(a.Magnitude,1e-9)end end
local Vector3={new=v,zero=v(0,0,0)}
local nativeTypeof=typeof
local function typeof(x)local mt=type(x)=="table"and getmetatable(x);return mt and mt.__type or nativeTypeof(x)end
local cf={X=1,Y=2,Z=3,LookVector=v(0,0,-1),GetComponents=function()return 1,2,3,1,0,0,0,1,0,0,0,1 end}
local Enum={KeyCode={},RaycastFilterType={Exclude="Exclude"}}
for _,k in ipairs({"W","A","S","D","Space","LeftShift","RightShift","LeftControl","RightControl","Q","E"})do Enum.KeyCode[k]={Name=k}end
local RaycastParams={new=function()return {}end}
local function object(name,class,children)
 local o={Name=name,ClassName=class,children=children or{},attrs={},signals={},DescendantAdded=signal(),DescendantRemoving=signal(),Parent=true}
 function o:IsA(t)return self.ClassName==t or t=="BaseRemoteEvent"and(self.ClassName=="RemoteEvent"or self.ClassName=="UnreliableRemoteEvent")or t=="BasePart"and self.ClassName=="Part"or t=="ValueBase"and(self.ClassName=="StringValue"or self.ClassName=="NumberValue")end
 function o:GetChildren()return self.children end
 function o:GetDescendants()local a={};for _,child in ipairs(self.children)do a[#a+1]=child;for _,x in ipairs(child:GetDescendants())do a[#a+1]=x end end;return a end
 function o:FindFirstChild(n)for _,child in ipairs(self.children)do if child.Name==n then return child end end end
 function o:FindFirstChildOfClass(c)for _,child in ipairs(self.children)do if child.ClassName==c then return child end end end
 function o:GetPropertyChangedSignal(n)self.signals[n]=self.signals[n]or signal();return self.signals[n]end
 function o:GetAttributes()return self.attrs end
 function o:GetAttribute(k)return self.attrs[k]end
 function o:GetFullName()methodName="GetFullName";return "Fixture."..self.Name end
 return setmetatable(o,{__type="Instance"})
end
local function character()
 local r=object("HumanoidRootPart","Part");r.Position=v(1,2,3);r.CFrame=cf;r.AssemblyLinearVelocity=v(0,0,0);r.AssemblyAngularVelocity=v(0,0,0);r.Anchored=false;r.CanCollide=false;r.CollisionGroup="Default"
 local h=object("Humanoid","Humanoid");h.MoveDirection=v(0,0,1);h.WalkToPoint=v(10,2,3);h.WalkSpeed=16;h.HipHeight=2;h.JumpPower=50;h.JumpHeight=7;h.Jump=false;h.FloorMaterial={Name="Grass"};h.Health=100;h.MaxHealth=100;h.AutoRotate=false;h.PlatformStand=false;h.Sit=false;h.UseJumpPower=true;h.StateChanged=signal();h.HealthChanged=signal()
 function h:GetState()return {Name="Running"}end
 local c=object("Character","Model",{r,h});return c,r,h
end
local c,part,hum=character()
local backpack=object("Backpack","Backpack",{object("Rifle","Tool")})
local p=object("Tester","Player",{backpack});p.UserId=123;p.Character=c
local quest=object("Quest","Folder",{object("CurrentQuest","StringValue"),object("Progress","NumberValue")});quest.children[1].Value="BanditQuest";quest.children[2].Value=1
local stats=object("StatsTester","Folder",{quest})
local remote=object("climb","RemoteEvent");remote.OnClientEvent=signal()
local lastNativeArgs;local function fireNative(_,...)lastNativeArgs=table.pack(...);return nil,false end
local function invokeNative(_,...)local args=table.pack(...);lastNativeArgs=args;if args[1]=="throw"then error("fixture_failure",0)elseif args[1]=="yield"then coroutine.yield("waiting")end;return nil,false,args.n end
remote.FireServer=fireNative
local remoteFn=object("CombatRegister","RemoteFunction");remoteFn.InvokeServer=invokeNative
local unreliable=object("opaque42","UnreliableRemoteEvent");unreliable.FireServer=fireNative;unreliable.OnClientEvent=signal()
local storage=object("Storage","Folder",{stats,object("Events","Folder",{remote,remoteFn,unreliable})})
local Input={InputBegan=signal(),InputEnded=signal(),WindowFocusReleased=signal(),WindowFocused=signal()}
function Input:GetFocusedTextBox()return nil end
function Input:IsKeyDown()return false end
local function encode(x)
 local t=type(x)
 if t=="nil"then return "null"elseif t=="boolean"or t=="number"then return tostring(x)elseif t=="string"then return string.format("%q",x)end
 local arr=#x>0;local out={}
 if arr then for i=1,#x do out[#out+1]=encode(x[i])end;return "["..table.concat(out,",").."]"end
 for k,v in pairs(x)do out[#out+1]=encode(tostring(k))..":"..encode(v)end
 return "{"..table.concat(out,",").."}"
end
local guid=0;local H={GenerateGUID=function()guid+=1;return "capture-"..guid end,JSONEncode=function(_,data)return encode(data)end}
local game={PlaceId=3978370137,GameId=648454481,JobId="job",GetService=function(_,s)return ({Players={LocalPlayer=p},HttpService=H,RunService={},UserInputService=Input,ReplicatedStorage=storage})[s]end}
local function nativeNamecall(object,...)return object[methodName](object,...)end
local function nativeIndex(object,key)return object[key]end
local mt={__namecall=nativeNamecall,__index=nativeIndex}
local function hookmetamethod(_,name,fn)local previous=mt[name];mt[name]=fn;return previous end
local function newcclosure(fn)return fn end
local function getrawmetatable()return mt end
local function getnamecallmethod()return methodName end
local function setnamecallmethod(name)methodName=name end
local function checkcaller()return true end
local function getcallingscript()return nil end
local workspace=object("Workspace","Workspace");function workspace:Raycast()return nil end
local disk={};local appended={};local failAppend=false;local failWrite=false
local function writefile(path,text)if failWrite then error("disk failed")end;disk[path]=text end
local function appendfile(path,text)if failAppend then error("append failed")end;assert(disk[path]~=nil);if #text>8192 then return end;disk[path]=disk[path]..text;appended[#appended+1]={path=path,text=text}end
local function readfile(path)return assert(disk[path])end
local folders={};local function isfolder(path)return folders[path]end;local function makefolder(path)folders[path]=true end
local jobs={};local task={spawn=function(fn)jobs[#jobs+1]=fn end,wait=function()end}
local R=(function()
-- SOURCE
end)()
assert(R:Coordinates()=="CFrame.new(1.00000, 2.00000, 3.00000)")
local snapshot=R:Snapshot("Point","Note");assert(disk[snapshot]and #R.last.points[1].cframe==12)
local path=R:Start("Movement","Start");assert(path:sub(-6)==".jsonl"and disk[path]=="")
assert(R.outbound.status=="installed"and R.outbound.direct.RemoteFunction=="future_lookups"and R.outbound.direct.UnreliableRemoteEvent=="future_lookups")
local unrelated=object("TweenService","TweenService");unrelated.Create=function(_,target,info,props)return target,info,props end
methodName="Create";local untouched=table.pack(mt.__namecall(unrelated,part,nil,false))
assert(untouched.n==3 and untouched[1]==part and untouched[2]==nil and untouched[3]==false,"unrelated reflected method changed")
assert(mt.__index(unrelated,"Name")=="TweenService","unrelated property lookup changed")
-- Namecall plus direct engine method hook records one call, preserving nils/false.
methodName="InvokeServer"
local beforeOut=R.outbound.recorded;local reply=table.pack(mt.__namecall(remoteFn,"damage",nil,false))
assert(reply.n==3 and reply[1]==nil and reply[2]==false and reply[3]==3 and lastNativeArgs.n==3)
assert(R.outbound.recorded==beforeOut+1,"namecall/direct double log")
local savedMethod=mt.__index(remoteFn,"InvokeServer")
local directReply=table.pack(savedMethod(remoteFn,"damage",nil,false))
assert(directReply.n==3 and directReply[2]==false and R.outbound.recorded==beforeOut+2,"dot/cached function call missing")
methodName="InvokeServer"
local failed,err=pcall(mt.__namecall,remoteFn,"throw");assert(not failed and err=="fixture_failure","original error changed")
local thread=coroutine.create(function()return mt.__namecall(remoteFn,"yield",nil,false)end)
local firstResume=table.pack(coroutine.resume(thread));assert(firstResume[2]=="waiting")
local finalResume=table.pack(coroutine.resume(thread));assert(finalResume.n==4 and finalResume[2]==nil and finalResume[3]==false and finalResume[4]==3,"yield/return semantics changed")
methodName="FireServer";mt.__namecall(unreliable,"Start",{token="DO_NOT_CAPTURE",Count=2})
R:Flush();assert(not disk[path]:find("DO_NOT_CAPTURE",1,true)and disk[path]:find('"executor":true',1,true)and disk[path]:find('"kind":"outbound_result"',1,true))
assert(not pcall(function()R:Start("Duplicate","")end))
R:Tick(.02);R:Flush()
local first=disk[path]
assert(first:find('"kind":"frame"',1,true)and first:find('"autoRotate":false',1,true),"false values or frames lost")
remote.OnClientEvent:Fire("Start",{Method="Craft",Secret="DO_NOT_CAPTURE"},"DO_NOT_CAPTURE")
R:Flush();local receipt=disk[path]
assert(receipt:find('"kind":"server_event"',1,true)and not receipt:find('DO_NOT_CAPTURE',1,true),"inbound payload leaked unrelated strings")
hum.StateChanged:Fire({Name="Running"},{Name="Climbing"});hum.WalkSpeed=40;hum:GetPropertyChangedSignal("WalkSpeed"):Fire()
-- Observe actual signals without firing a weapon or touching a remote.
local tool=object("TestRifle","Tool");tool.Activated=signal();tool.Deactivated=signal();tool.Equipped=signal();tool.Unequipped=signal();tool.Enabled=true
R:WatchTool(tool);R:WatchTool(tool);tool.Activated:Fire();tool.Deactivated:Fire()
local npc,rootNpc,hNpc=character();npc.Name="Bandit"
R:WatchNpc({model=npc,h=hNpc,root=rootNpc});R:WatchNpc({model=npc,h=hNpc,root=rootNpc})
hNpc.HealthChanged:Fire(95);hNpc.StateChanged:Fire({Name="Running"},{Name="FallingDown"})
hum.HealthChanged:Fire(96);now+=.25;R:Tick(.25);now+=2;R:Tick(.02)
local attachment=object("ClimbSurface","Attachment");attachment.Position=v(1,2,3);attachment.WorldPosition=v(4,5,6)
local force=object("Velocity","LinearVelocity");force.Attachment0=attachment;force.PrimaryTangentAxis=v(1,0,0);force.PlaneVelocity=setmetatable({X=43,Y=0},{__type="Vector2"})
local forceData=R:Force(force);assert(forceData.properties.PlaneVelocity[1]==43 and forceData.attachments.Attachment0.worldPosition[2]==5)
R:Flush();local extended=disk[path]
for _,kind in ipairs({"tool_action","npc_health","npc_state","damage_episode","motion_window","walk_goal"})do assert(extended:find('"kind":"'..kind..'"',1,true),"missing "..kind)end
assert(extended:find('"delta":-5',1,true)and extended:find('"phase":"after_2s"',1,true))
-- Short-lived markers and stopped animations are event-driven, not only10Hz snapshots.
local marker=object("Stun","BoolValue");marker.Value=true;table.insert(c.children,marker);c.DescendantAdded:Fire(marker)
R:Tick(.01);now+=.002;c.DescendantRemoving:Fire(marker);table.remove(c.children)
hum.WalkSpeed=0;R:Tick(.01);now+=.6;hum.WalkSpeed=16;hum.MoveDirection=v(1,0,0);part.AssemblyLinearVelocity=v(3,0,0);R:Tick(.01)
local track=object("Punch1","AnimationTrack");track.Animation={AnimationId="rbxassetid://123"};track.Priority="Action";track.Speed=1;track.TimePosition=.1;track.WeightCurrent=0;track.WeightTarget=0;track.IsPlaying=false
track.Stopped=signal();track.Ended=signal();track.DidLoop=signal();R:WatchAnimation(track,true);track.Stopped:Fire();track.Ended:Fire();assert(not R.trackWatches[track])
R:WatchForce(force);force.PlaneVelocity=v(0,0,0);force:GetPropertyChangedSignal("PlaneVelocity"):Fire()
methodName="Destroy";marker.Destroy=function()return "unchanged"end;R.markerTimes[marker]=now
assert(mt.__namecall(marker)=="unchanged")
R:Flush();local deep=disk[path]
for _,kind in ipairs({"marker_removed","control_transition","control_recovery","animation_lifecycle","force_property","client_action"})do assert(deep:find('"kind":"'..kind..'"',1,true),"missing diagnostic "..kind)end
local cyclic={};cyclic.self=cyclic;cyclic.token="DO_NOT_CAPTURE"
methodName="InvokeServer";mt.__namecall(remoteFn,cyclic)
local authRemote=object("AuthKey","RemoteFunction");authRemote.InvokeServer=invokeNative;mt.__namecall(authRemote,"short-secret")
R:Flush();assert(not disk[path]:find("DO_NOT_CAPTURE",1,true)and not disk[path]:find("short-secret",1,true),"sensitive or cyclic capture failure")
local before=R.seq;R:ClearNpcs();hNpc.HealthChanged:Fire(90);assert(R.seq==before,"NPC listener survived cleanup")
for i=1,80 do R:WatchTool(object("extra"..i,"Tool"))end;assert(R.toolWatchCount==64,"unbounded tool listeners")
R:Snapshot("Wall","Start climbing");assert(#R.current.markers==1)
R:UpdateNotes("Castle","Walk and climb");assert(R.current.title=="Castle")
for i=1,8000 do now+=.02;R:Tick(.02);if i%50==0 then assert(R:Flush());disk[path]=""end end
assert(R.appendVerified,"first append was not read back")
assert(R.current and R.samples>=8000 and #R.current.points<=2,"old time/sample cap or unbounded point storage")
p.Character=nil;now+=1;R:Tick(.02);assert(R.current,"respawn stopped capture")
p.Character=character();now+=1;R:Tick(.02);assert(R.current and R.epoch>=3,"character rebind failed")
now+=36000;R:Tick(.02);assert(R.current,"recording acquired a duration limit")
failAppend=true;assert(not R:Flush());local pending=#R.queue;assert(pending>0 and R.current,"I/O failure lost buffer or stopped recorder")
now+=.02;R:Tick(.02);assert(#R.queue>pending)
failAppend=false;assert(R:Flush()and #R.queue==0)
R.maxQueueRows=5
for i=1,30 do R:Emit("fixture",{index=i})end
assert(#R.queue==5 and R.dropped>0 and R.current,"queue bound or continued capture broken")
R.maxQueueRows=5000;R:Flush()
R.outbound.window=now;R.outbound.windowCount=1000;local beforeLimited=R.seq
assert(R:CaptureCall(remote,"FireServer",table.pack("Start"),true)==nil and R.seq==beforeLimited and R.outbound.rateLimited>0,"rate limit was silent or did not bound work")
local done=R:Stop();assert(done==path and not R.current and not R.finishing and R.last.state=="stopped")
local markerSeq=R.seq;track.Stopped:Fire();force:GetPropertyChangedSignal("PlaneVelocity"):Fire();assert(R.seq==markerSeq,"diagnostic listener survived Stop")
assert(mt.__namecall==nativeNamecall,"owned namecall hook survived unload")
assert(mt.__index==nativeIndex,"owned index hook survived unload")
local beforeDormant=R.seq;savedMethod(remoteFn,"Start");assert(R.seq==beforeDormant,"saved proxy recorded after Stop")
local realHook=hookmetamethod;hookmetamethod=nil
R:Start("Unsupported","");assert(R.outbound.status=="unsupported","missing capability was reported as active");R:Stop();hookmetamethod=realHook
R:Start("Foreign owner","")
local ownedNamecall=mt.__namecall;local foreignNamecall=function(...)return ownedNamecall(...)end
mt.__namecall=foreignNamecall;R.lastTapSeen=R.outbound.seen;R:CheckObservation();assert(R.outbound.status=="chain_unverified")
R:Stop();assert(mt.__namecall==foreignNamecall,"Stop removed a foreign hook")
R:Start("Again","");R:Unload();assert(not R.alive and not R.current and not pcall(function()R:Start("No","")end))
assert(mt.__namecall==foreignNamecall and mt.__index==nativeIndex,"unload modified another owner's method hook")
print("PASS: actual backend frames, property events, redacted receipts, snapshot/marker/notes, 8000+ frames without cap, respawn, ten-hour time advance, disk retry, bounded queue, Stop/restart/unload")
'''.replace('-- SOURCE',source)
with tempfile.TemporaryDirectory()as d:
 path=Path(d)/'fixture.luau';path.write_text(fixture,encoding='utf-8');subprocess.run([runtime,str(path)],check=True)
assert 'loadstring =' not in whole and 'restorefunction(' not in source and 'hookfunction(' not in source
assert 'self.limit' not in source and 'Stop("Character changed' not in source
print('PASS: owned observation-only taps, no gameplay mutation/code hook or former sample cap')
from analyze_recording import analyze
with tempfile.TemporaryDirectory()as directory:
    path=Path(directory)/'session.jsonl'
    rows=[{'seq':1,'t':0,'kind':'session_start','capture':{'outboundRemotes':True}},
          {'seq':2,'t':1,'kind':'outbound_call','callId':1,'method':'InvokeServer','object':{'path':'Events.CombatRegister'}},
          {'seq':3,'t':1.1,'kind':'outbound_result','callId':1,'ok':True,'duration':.1},
          {'seq':4,'t':2,'kind':'control_recovery','phase':'direction_intent','delay':.016}]
    path.write_text(''.join(json.dumps(row)+'\n'for row in rows),encoding='utf-8')
    report=analyze(path);d=report['diagnostics']
    assert d['pendingInvokeResults']==0 and d['invokeErrors']==0 and d['timings']['control_direction_intent']['mean']==.016
    assert report['sequenceGapCount']==0 and d['captureScope']['outboundRemotes']
print('PASS: streaming outgoing/recovery analyzer and correlated reply IDs')
