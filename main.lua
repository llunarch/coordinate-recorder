--!nocheck
-- Standalone passive recorder. Own UI, no library, localization or gameplay hooks.
local env=getgenv();local previous=env.__StandaloneCoordinateRecorder
if previous and previous.Cleanup then previous:Cleanup()end
local state={alive=true,connections={}};env.__StandaloneCoordinateRecorder=state
local recorder=(function()
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
local function connect(signal,fn)local c=signal:Connect(fn);state.connections[#state.connections+1]=c;return c end
local function corner(o,r)new("UICorner",{CornerRadius=UDim.new(0,r)},o)end
local gui=new("ScreenGui",{Name="CoordinateRecorderStandalone",ResetOnSpawn=false,IgnoreGuiInset=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=80},gethui and gethui()or game:GetService("CoreGui"))
local window=new("Frame",{Name="Window",Size=UDim2.fromOffset(800,510),AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),BackgroundColor3=colors.background,BorderSizePixel=0,Active=true},gui)
corner(window,12);new("UIStroke",{Color=colors.border,Thickness=1},window)
local bar=new("Frame",{Name="Titlebar",Size=UDim2.new(1,0,0,42),BackgroundTransparency=1,Active=true},window)
new("TextLabel",{Text="Coordinate Recorder",Font=Enum.Font.BuilderSansBold,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Position=UDim2.fromOffset(18,0),Size=UDim2.new(1,-110,1,0),Active=false},bar)
new("Frame",{Name="Divider",Position=UDim2.new(0,16,0,42),Size=UDim2.new(1,-32,0,1),BackgroundColor3=colors.border,BackgroundTransparency=.55,BorderSizePixel=0},window)
function state:Cleanup()
 if not self.alive then return end
 self.alive=false;recorder:Unload()
 for _,c in ipairs(self.connections)do c:Disconnect()end
 gui:Destroy()
 if env.__StandaloneCoordinateRecorder==self then env.__StandaloneCoordinateRecorder=nil end
end
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
button(routes,"Start Recording",126,function()recorder:Start(title.Text,description.Text);return "Recording every 0.5s; autosave every 5s"end,true)
button(routes,"Stop and Save",166,function()return recorder:Stop()or"No active recording"end)
button(routes,"Update Recording Notes",206,function()return recorder:UpdateNotes(title.Text,description.Text)end)
button(routes,"Copy Last File Path",246,function()local path=assert(recorder.lastPath,"No saved file");setclipboard(path);return path end)
button(routes,"Copy Last JSON",286,function()setclipboard(game:GetService("HttpService"):JSONEncode(assert(recorder.last,"No recording or snapshot")));return "JSON copied"end)
label(routes,"Samples: 0.5s  •  Autosave: 5s",330)
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
 recorder:Tick();tick+=dt;if tick<.25 then return end;tick=0
 local message=recorder.status
 if message:sub(1,6)=="Saved:"then message="Saved successfully"end
 status.Text=message.."\n"..recorder.folder
end)
return state
