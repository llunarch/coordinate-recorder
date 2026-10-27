from pathlib import Path
import subprocess,sys,tempfile,json
root=Path(__file__).resolve().parent
runtime=sys.argv[1]
whole=(root/'main.lua').read_text(encoding='utf-8')
source=whole[whole.index('-- Passive owner-local survey'):whole.index('end)()')]
fixture=r'''local now=0
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
 function o:IsA(t)return self.ClassName==t or t=="BasePart"and self.ClassName=="Part"or t=="ValueBase"and(self.ClassName=="StringValue"or self.ClassName=="NumberValue")end
 function o:GetChildren()return self.children end
 function o:GetDescendants()local a={};for _,child in ipairs(self.children)do a[#a+1]=child;for _,x in ipairs(child:GetDescendants())do a[#a+1]=x end end;return a end
 function o:FindFirstChild(n)for _,child in ipairs(self.children)do if child.Name==n then return child end end end
 function o:FindFirstChildOfClass(c)for _,child in ipairs(self.children)do if child.ClassName==c then return child end end end
 function o:GetPropertyChangedSignal(n)self.signals[n]=self.signals[n]or signal();return self.signals[n]end
 function o:GetAttributes()return self.attrs end
 function o:GetFullName()return "Fixture."..self.Name end
 return o
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
local storage=object("Storage","Folder",{stats,object("Events","Folder",{remote})})
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
assert(not pcall(function()R:Start("Duplicate","")end))
R:Tick(.02);R:Flush()
local first=disk[path]
assert(first:find('"kind":"frame"',1,true)and first:find('"autoRotate":false',1,true),"false values or frames lost")
remote.OnClientEvent:Fire("Start",{Method="Craft",Secret="DO_NOT_CAPTURE"},"DO_NOT_CAPTURE")
R:Flush();local receipt=disk[path]
assert(receipt:find('"kind":"server_event"',1,true)and not receipt:find('DO_NOT_CAPTURE',1,true),"inbound payload leaked unrelated strings")
hum.StateChanged:Fire({Name="Running"},{Name="Climbing"});hum.WalkSpeed=40;hum:GetPropertyChangedSignal("WalkSpeed"):Fire()
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
local done=R:Stop();assert(done==path and not R.current and not R.finishing and R.last.state=="stopped")
R:Start("Again","");R:Unload();assert(not R.alive and not R.current and not pcall(function()R:Start("No","")end))
print("PASS: actual backend frames, property events, redacted receipts, snapshot/marker/notes, 8000+ frames without cap, respawn, ten-hour time advance, disk retry, bounded queue, Stop/restart/unload")
'''.replace('-- SOURCE',source)
with tempfile.TemporaryDirectory()as d:
 path=Path(d)/'fixture.luau';path.write_text(fixture,encoding='utf-8');subprocess.run([runtime,str(path)],check=True)
assert 'hookfunction(' not in whole and 'hookmetamethod(' not in whole and '__namecall' not in whole
assert 'self.limit' not in source and 'Stop("Character changed' not in source
print('PASS: no gameplay/global hooks or former sample cap')
