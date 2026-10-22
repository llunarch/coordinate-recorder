from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parent
import shutil,sys
runtime=sys.argv[1]if len(sys.argv)>1 else shutil.which('luau')
if not runtime:raise SystemExit('Pass Luau CLI path or add luau to PATH')
whole=Path('main.lua').read_text(encoding='utf-8');source=whole[whole.index('-- Passive owner-local survey'):whole.index('end)()')]
t=r'''
local now=0;local os={time=function()return 1000+now end,clock=function()return now end}
local cf={X=1,Y=2,Z=3,GetComponents=function()return 1,2,3,1,0,0,0,1,0,0,0,1 end}
local root={CFrame=cf};local character={FindFirstChild=function()return root end};local p={UserId=123,Character=character}
local S={};local getgenv=function()return {AUTAir45=S}end
local guid=0;local H={GenerateGUID=function()guid+=1;return 'record-'..guid end,JSONEncode=function(_,data)return data.id end}
local game={Players={LocalPlayer=p},PlaceId=6846458508,JobId='job',GetService=function()return H end}
local folders={};local isfolder=function(v)return folders[v]end;local makefolder=function(v)folders[v]=true end
local disk={};local writes=0;local fail=false;local writefile=function(path,text)if fail then error('disk unavailable')end;writes+=1;disk[path]=text end
local function module()
-- SOURCE
end
local R=module()
assert(R:Coordinates()=='CFrame.new(1.00000, 2.00000, 3.00000)')
local file=R:Snapshot('Meteor','Standing on Rock');assert(disk[file]and R.last.title=='Meteor'and #R.last.points[1].cframe==12)
R:Start('Crates','Start here');local route=R.current;assert(#route.points==1 and route.placeId==6846458508)
assert(not pcall(function()R:Start('duplicate','')end),'cannot stack recorders')
now=.4;R:Tick();assert(#route.points==1);now=.5;R:Tick();assert(#route.points==2)
R:Snapshot('Crate','Behind building');assert(#route.markers==1 and route.markers[1].point.position[1]==1)
local before=writes;now=5;R:Tick();assert(writes>before,'checkpoint saves before user Stop')
R:UpdateNotes('Crate route','Revised');assert(route.title=='Crate route')
R:Stop();assert(not R.current and route.state=='stopped'and route.stopReason=='User Stop')
R:Start('Respawn','');p.Character={};R:Tick();assert(not R.current and R.last.stopReason=='Character changed/unavailable')
p.Character=character;R.limit=2;R:Start('Bounded','');now+=1;R:Tick();assert(not R.current and #R.last.points==2 and R.last.stopReason=='Sample limit reached')
R.limit=7200;R:Start('Failure','');fail=true;now+=6;R:Tick();assert(not R.current and R.last.title=='Failure'and R.last.state=='save-error','disk failure stops recording but keeps recoverable JSON')
fail=false;R:Start('Unload','');R:Unload();assert(not R.alive and not R.current and R.last.stopReason=='Runtime unloaded')
assert(not pcall(function()R:Start('No','')end))
print('PASS actual survey snapshot/CFrame, notes/markers, interval/checkpoint, duplicate guard, Stop/respawn/limit/unload and disk-failure recovery')
'''.replace('-- SOURCE',source)
with tempfile.TemporaryDirectory()as d:
 pth=Path(d)/'survey.luau';pth.write_text(t,encoding='utf-8');subprocess.run([runtime,str(pth)],check=True)
