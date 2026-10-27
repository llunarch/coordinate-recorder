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
# Extended passive combat and movement recording

Tool Activated/Deactivated/Equipped/Unequipped signals are recorded separately from input and animation observations. These are attempts/state changes, not proof of a server-accepted attack. The nearest 12 NPCs are discovered once per second, with event-driven HP/state listeners while tracked; an HP decrease does not identify its attacker. A native Tool signal may be absent when a hub invokes combat directly. No outgoing remote interception or global hook is installed.

Movement includes 0.2-second path-speed windows, potential stalls (forward intent with speed below 1), changed WalkToPoint destinations, LinearVelocity plane/line settings and both constraint attachments' local/world positions. Windows include setup/transitions and are not a universal route benchmark. Damage events have IDs, HP deltas, associated marker events, nearby detail samples and an after-two-seconds observation; a new hit supersedes the previous pending follow-up. Rebind/Stop clears listeners and windows. Tool subscriptions are capped at 64 per character, NPCs at 12 concurrently. Existing JSONL files remain readable; these fields appear only in new captures.
