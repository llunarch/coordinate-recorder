--!nocheck
-- Standalone passive coordinate recorder; no AUT runtime or gameplay dependencies.
local env=getgenv()
local previous=env.__StandaloneCoordinateRecorder
if previous and previous.Cleanup then previous:Cleanup()end
local state={alive=true,connections={}}
env.__StandaloneCoordinateRecorder=state
local library=game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/1.6.66/dist/main.lua")
-- Give this library instance its own GUI names; never remove another script's UI.
library=library:gsub('Name="WindUI','Name="CoordinateRecorder')
local WindUI=assert(loadstring(library))()
local Window=WindUI:CreateWindow({Title="Coordinate Recorder",Author="",Icon="map-pin",Folder="CoordinateRecorderUI",Size=UDim2.fromOffset(780,530),MinSize=Vector2.new(560,340),Theme="Dark",Resizable=true,ToggleKey=Enum.KeyCode.RightControl,User={Enabled=false}})
local Panel={alive=true,connections={}}
local recorder=(function()
--!nocheck
-- Passive owner-local survey data, never part of gameplay configs or source control.
local S={};local p=game.Players.LocalPlayer
local H=game:GetService("HttpService")
local R={alive=true,status="Ready",interval=.5,limit=7200,folder="CoordinateRecorder/records/"..p.UserId}
S.recorder=R
function R:Pose()
 local c=p.Character;local root=c and c:FindFirstChild("HumanoidRootPart")
 if not root then return end
 local cf=root.CFrame;return {position={cf.X,cf.Y,cf.Z},cframe={cf:GetComponents()},time=os.time()}
end
function R:Coordinates()
 local point=assert(self:Pose(),"Character position unavailable")
 local v=point.position;return string.format("CFrame.new(%.5f, %.5f, %.5f)",v[1],v[2],v[3])
end
function R:New(kind,title,description)
 assert(type(title)=="string"and #title<=256,"Name must be at most 256 bytes")
 assert(type(description)=="string"and #description<=4096,"Description must be at most 4096 bytes")
 return {schema=1,id=H:GenerateGUID(false),kind=kind,title=title~=""and title or(kind=="route"and"Route"or"Point"),description=description,userId=p.UserId,placeId=game.PlaceId,jobId=game.JobId,createdAt=os.time(),interval=kind=="route"and self.interval or nil,points={},markers={}}
end
function R:Save(data)
 for _,folder in ipairs({"CoordinateRecorder","CoordinateRecorder/records",self.folder})do if not isfolder(folder)then makefolder(folder)end end
 local path=self.folder.."/"..data.id..".json"
 self.last=data
 writefile(path,H:JSONEncode(data))
 self.last=data;self.lastPath=path;self.status="Saved: "..path
 return path
end
function R:Snapshot(title,description)
 local point=assert(self:Pose(),"Character position unavailable")
 local data=self:New("point",title,description);data.points[1]=point
 local path=self:Save(data)
 if self.current then
  self.current.markers[#self.current.markers+1]={title=data.title,description=data.description,point=point,elapsed=os.clock()-self.started}
  self:Save(self.current)
 end
 return path
end
function R:Start(title,description)
 assert(self.alive and not self.current,"Recording already active")
 local point=assert(self:Pose(),"Character position unavailable")
 local data=self:New("route",title,description);point.elapsed=0;data.points[1]=point;data.state="recording"
 self:Save(data);self.current=data;self.character=p.Character;self.started=os.clock();self.sampleAt=self.started;self.saveAt=self.started
 self.status="Recording: "..data.title
end
function R:Stop(reason)
 local data=self.current;if not data then return self.lastPath end
 self.current=nil
 local point=self.character==p.Character and self:Pose()
 if point and #data.points<self.limit then point.elapsed=os.clock()-self.started;data.points[#data.points+1]=point end
 data.state="stopped";data.stopReason=reason or"User Stop";data.finishedAt=os.time();data.duration=os.clock()-self.started
 -- Retain data in memory even when a disk write fails; Copy Last JSON can recover it.
 self.last=data;return self:Save(data)
end
function R:UpdateNotes(title,description)
 local data=assert(self.current,"Start recording first")
 assert(#title<=256 and #description<=4096,"Notes too long")
 data.title=title~=""and title or data.title;data.description=description;return self:Save(data)
end
function R:Tick()
 local data=self.current;if not self.alive or not data then return end
 local ok,err=pcall(function()
  if p.Character~=self.character or not self:Pose()then return self:Stop("Character changed/unavailable")end
  local now=os.clock()
  if now-self.sampleAt>=self.interval then
   self.sampleAt=now;local point=self:Pose();point.elapsed=now-self.started;data.points[#data.points+1]=point
   if #data.points>=self.limit then return self:Stop("Sample limit reached")end
  end
  if now-self.saveAt>=5 then self:Save(data);self.saveAt=now end
  self.status="Recording: "..#data.points.." points / "..math.floor(now-self.started).."s"
 end)
 if not ok then data.state="save-error";self.last=data;self.current=nil;self.status="Recording stopped: "..tostring(err)end
end
function R:Unload()
 if not self.alive then return end
 local ok,err=pcall(function()self:Stop("Runtime unloaded")end)
 self.alive=false;if not ok then self.status=tostring(err)end
end
function R:BuildPanel(ctx)
 local tab=ctx.Window:Tab({Title="Test",Icon="map-pin"});ctx.Panel.testTab=tab
 local left,right=ctx.columns(tab);local points=ctx.section(left,"Coordinate Notes","map-pin");local recording=ctx.section(right,"Route Recording","route")
 local function textRow(section,name,height,editable)
  local row=section:Button({Title="",Callback=function()end}).ElementFrame
  for _,v in ipairs(row:GetChildren())do if v:IsA("GuiObject")then v.Visible=false end end
  row.Size=UDim2.new(1,0,0,height);row.AutomaticSize=Enum.AutomaticSize.None
  local input=ctx.new(editable and"TextBox"or"TextLabel",{Name=name,Text="",PlaceholderText=editable and name or nil,ClearTextOnFocus=editable and false or nil,MultiLine=editable and height>40 or nil,TextWrapped=true,TextSize=14,TextColor3=Color3.fromRGB(230,230,235),BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Size=UDim2.new(1,-16,1,-12),Position=UDim2.fromOffset(8,6)},row)
  if editable then input.ClearTextOnFocus=false end
  return input
 end
 local title=textRow(points,"Name",40,true);local description=textRow(points,"Description",100,true)
 local status=textRow(recording,"RecorderStatus",78,false)
 local function action(fn)
  local ok,result=pcall(fn);ctx.WindUI:Notify({Title="Test",Content=ok and tostring(result or"Done")or tostring(result),Duration=5})
 end
 points:Button({Title="Copy Current Coordinates",Icon="copy",Callback=function()action(function()local value=self:Coordinates();setclipboard(value);return value end)end})
 points:Button({Title="Save Snapshot / Add Marker",Icon="map-pin",Callback=function()action(function()return self:Snapshot(title.Text,description.Text)end)end})
 recording:Button({Title="Start Recording",Icon="play",Callback=function()action(function()self:Start(title.Text,description.Text);return "Recording every 0.5s; autosave every 5s"end)end})
 recording:Button({Title="Stop and Save",Icon="square",Callback=function()action(function()return self:Stop()or"No recording"end)end})
 recording:Button({Title="Update Recording Notes",Icon="pencil",Callback=function()action(function()return self:UpdateNotes(title.Text,description.Text)end)end})
 recording:Button({Title="Copy Last File Path",Icon="copy",Callback=function()action(function()setclipboard(assert(self.lastPath,"No saved file"));return self.lastPath end)end})
 recording:Button({Title="Copy Last JSON",Icon="copy",Callback=function()action(function()setclipboard(H:JSONEncode(assert(self.last,"No recording or snapshot")));return "JSON copied"end)end})
 local clock=0
 table.insert(ctx.Panel.connections,game:GetService("RunService").Heartbeat:Connect(function(dt)
  if not ctx.Panel.alive then return end
  self:Tick();clock+=dt;if clock<.25 then return end;clock=0
  status.Text=self.status.."\n"..self.folder
 end))
end
return R

end)()
state.recorder=recorder
function state:Cleanup(fromWindow)
 if not self.alive then return end
 self.alive=false;Panel.alive=false
 recorder:Unload()
 for _,connection in ipairs(Panel.connections)do connection:Disconnect()end
 if not fromWindow then pcall(function()Window:Destroy()end)end
 for _,key in ipairs({"ScreenGui","NotificationGui","DropdownGui","TooltipGui"})do local gui=WindUI[key];if gui then pcall(function()gui:Destroy()end)end end
 if env.__StandaloneCoordinateRecorder==self then env.__StandaloneCoordinateRecorder=nil end
end
local function new(class,properties,parent)
 local object=Instance.new(class)
 for key,value in pairs(properties)do object[key]=value end
 object.Parent=parent;return object
end
recorder:BuildPanel({Panel=Panel,Window=Window,WindUI=WindUI,new=new,
 columns=function(tab)local row=tab:HStack({});return row:VStack({}),row:VStack({})end,
 section=function(parent,title,icon)return parent:Section({Title=title,Icon=icon,TextSize=16,Box=true,BoxBorder=true,Opened=true})end})
Window:OnDestroy(function()state:Cleanup(true)end)
Window:SelectTab(1)
return state
