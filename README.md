# Coordinate Recorder

Standalone passive Roblox recorder with the existing Umbrella-style window. Public code only; recordings stay in the executor workspace.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/llunarch/coordinate-recorder/main/main.lua"))()
```

Recording starts immediately by default. Set `getgenv().CoordinateRecorderAutoStart=false` before loading to start manually. Right Shift shows/hides the existing window; hiding does not stop recording. **Stop and Save** ends the session. Close/unload ends and saves it; Start starts a new file. Repeated execution cleans up only this recorder.

## Captured observations

- Every Heartbeat: position, full CFrame, assembly linear/angular velocity, measured displacement velocity, Humanoid state/MoveDirection/WalkToPoint, speed/jump/hip/health/floor/collision/control properties.
- About10Hz: active animation IDs/time/speed/weights, body movers and constraints (bounded48), movement-related attributes, movement keys, camera pose and seven local obstacle/support/ceiling probes with hit geometry.
- State/property/animation/constraint changes and movement-key/focus events between samples.
- About1Hz: native local quest fields and numeric progression, equipped/backpack Tool names, up to12 nearby NPCs (180stud) from recognized NPCs/Enemies/Mobs containers, with position/velocity/health/state.
- Passive OnClientEvent listeners for movement/quest/combat/fishing/shop/etc name matches under ReplicatedStorage.Events. Remote paths, timing and bounded argument shapes are recorded. Arbitrary strings and unapproved table fields are redacted; keys/session tokens/code are not recorded.

There are **no loadstring, function or namecall hooks**, no outgoing remote interception, no OnClientInvoke replacement, no changes to movement/collisions/physics and no automatic gameplay. This is observation of visible/native state, not extraction of another hub's source or complete coverage of its calls. Unsupported game layouts are marked unavailable; generic replicated observations do not prove intent, kill rewards or the route planner's algorithm.

## Local files

`CoordinateRecorder/records/<UserId>/<GUID>.jsonl` contains append-only timestamped events. `<GUID>.manifest.json` contains title/notes, scope, counters and file path. Snapshots remain separate JSON files and add streamed markers to an active session. **Copy Last File Path** gives the JSONL path; **Copy Session Manifest** copies metadata, not an ever-growing recording.

The writer flushes about every0.5seconds in UTF-8-safe blocks of at most8KiB, not by rewriting the full session. The first append batch is read back and checked; `appendVerified` in the manifest records that check. Small blocks avoid an observed Real failure where64KiB+ appends returned without writing bytes. No duration or total-sample limit; respawn records a new character epoch and continues. Roblox disconnect/rejoin destroys the injected runtime: reload in the new session. Abrupt process exits can lose the last unflushed batch.

RAM backlog is bounded to8MiB/5000rows, plus an in-flight batch. A prolonged disk failure drops oldest pending rows and increments `dropped`; recording remains enabled. Writes retry without restarting gameplay. Sequence numbers allow duplicate detection after uncertain append failures. A truncated last line after a crash must be ignored. Disk use grows until Stop; this is not an unlimited-storage or lossless guarantee. On unload, a failing final writer has at most3 shutdown retries.

## Validation

```text
python verify.py /path/to/luau
python analyze_recording.py /path/to/session.jsonl
```

Offline tests exercise the actual embedded backend: frames/false properties, redacted server receipts, snapshot/markers/notes,8000+frames,respawn,ten-hour time advance,disk retry,bounded backlog and teardown. These tests do not prove compatibility with every executor or third-party hub. Requires writefile/appendfile/readfile/isfolder/makefolder/getgenv and setclipboard for Copy buttons.
