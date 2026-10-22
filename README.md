# Coordinate Recorder

Standalone Roblox executor menu for passive coordinate notes and route recording.
No UmbrellaCat runtime, key system, AUT services, farming, movement or combat hooks.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/llunarch/coordinate-recorder/main/main.lua"))()
```

Right Ctrl toggles the menu. Fill Name and Description, then save a snapshot or
Start Recording / Stop and Save. A snapshot during recording also adds a marker.
Update Recording Notes changes the current route title/description.
Copy Current Coordinates, Copy Last JSON and Copy Last File Path are available.

Files: `CoordinateRecorder/records/<UserId>/<GUID>.json` inside your executor's
workspace. Samples every 0.5s; checkpoint every 5s; maximum7200 samples per route.
Each record contains place/job/user IDs, timestamps, XYZ, full CFrame and notes.
Respawn/unload stops recording. Re-injection cleans up only this recorder.
Disk-write failures retain the last data in memory for Copy Last JSON.
Records remain local; the script does not upload them. Review JSON before sharing.

Requires an executor with HttpGet, loadstring, getgenv, writefile, makefolder,
isfolder and setclipboard. UI dependency: [WindUI1.6.66](https://github.com/Footagesus/WindUI/tree/1.6.66), MIT licensed, loaded from its official source.

Offline compiler/recorder fixture checks passed. UI and simultaneous Vellure
operation have not been live-tested. This does not promise compatibility with
third-party scripts that intercept input or remove unrelated interfaces.
