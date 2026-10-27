# Coordinate Recorder

Standalone Umbrella-style recorder. Code is public; captures remain local in the executor workspace.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/llunarch/coordinate-recorder/main/main.lua"))()
```

Start the recorder **before loading the hub being observed**. Recording starts automatically, continues through character respawns and has no duration/sample cap. Right Shift only hides/shows the window. Stop and Save ends the capture; reloading cleans up this recorder. `CoordinateRecorderAutoStart=false` keeps manual start.

## Outgoing calls and attack evidence

Outgoing observation is enabled by default, including calls from executor code. It records RemoteEvent/UnreliableRemoteEvent FireServer and RemoteFunction InvokeServer without a name filter. Send and result rows share a callId; InvokeServer replies, errors, duration, nil/false arguments, remote/Instance references and available caller-script identity are preserved as bounded diagnostic data. A completed InvokeServer is not automatically an accepted attack.

An owned namecall observer records colon calls. An owned index observer returns pass-through diagnostic proxies for subsequently retrieved FireServer/InvokeServer functions, covering dot/cached-function calls obtained after recording starts. **Functions cached before the recorder starts are not covered by that proxy.** No shared native C function is replaced. Stop restores the exact metatable slots only when their function identity still proves ownership; otherwise its single broker becomes inert, preserving later hooks. Previously returned proxies also become inert. Start/reload reuses the broker instead of stacking copies.

The recording includes `capture_coverage` events, initial capability status and final manifest counters: raw seen calls, matching candidates, remote/client-action counts, errors, truncations, rate limits and maximum capture time. Zero events with unavailable/stalled coverage is not proof of no attacks. Some executors patch a closure without replacing its identity; `observing_chain` reports measured traffic rather than claiming direct ownership. Optional `CoordinateRecorderOutbound=false` disables both observers; `CoordinateRecorderDirectRemotes=false` disables method-lookup proxies.

Arguments are bounded to24 positions,4 table levels and96 total table entries. Cycles and truncation are explicit. Credentials/auth channels, sensitive fields, opaque or arbitrary long strings are redacted. No source/code interception, replay, argument replacement, remote blocking or automatic gameplay is performed.

## Movement, combat and stun detail

- Every Heartbeat: full root pose, measured/assembly velocity, movement direction, WalkToPoint, native state, speed/jump/hip/floor/health/collision properties, observed control transitions and time from release to direction intent/horizontal movement.
- About10Hz: animation IDs/time/weights/speed, forces/constraints/attachments, related attributes, keys, camera and7 obstacle/support probes.
- Event-driven: animation start/Stopped/Ended/DidLoop, movement/control attribute changes, marker add/remove and lifetime, humanoid/part properties, tool signals, force add/remove and selected property changes.
- Scoped method evidence: local character/Humanoid/root/Animator, tracked animation tracks and movement/stun markers, including Destroy/Remove, ChangeState/SetStateEnabled, Move/MoveTo, LoadAnimation, Play/Stop/AdjustWeight/AdjustSpeed and SetAttribute. This can distinguish an observed executor-origin marker removal from a replicated removal with no recorded client action; it does not expose the server implementation or every property assignment/internal Lua call.
- About1Hz: local quest/progression, tools and nearest12 NPCs within180studs. NPC HP/state listeners include relative player geometry, root/head positions/sizes and native identity at HP changes. HP loss alone does not identify its attacker.
- Filtered inbound Events listeners retain the prior string-redacted channel. OnClientInvoke callbacks are never replaced.

Short marker/animation lifetimes are recorded through events even if they occur between10Hz snapshots. Observed control flags and subsequent movement are evidence, not proof of server stun cancellation or immunity. Pure property assignments have native change events but no guaranteed writer identity.

## Local storage and limits

`CoordinateRecorder/records/<UserId>/<GUID>.jsonl` is append-only. `<GUID>.manifest.json` contains scope/counters/notes. Copy Last File Path gives the JSONL path; copy or retain its matching manifest too. Snapshots remain separate JSON files and streamed markers. Never commit captures/account data.

The writer flushes about every0.5s in UTF-8-safe chunks <=8192bytes and reads back its first append. This avoids an observed Real failure silently dropping64KiB appends. RAM backlog remains bounded to8MiB/5000rows plus one in-flight batch. Native diagnostics are capped at1000 matched calls/s and300 force-property events/s; limit counters are explicit. Tool watches64/character, NPC watches12, animation watches64 and force watches32 are bounded. Disk use grows until Stop; disk failure drops oldest queued rows with counters. Unload retries final writes at most3times. A disconnect/rejoin destroys injected state; load again in the new client. These are not lossless/full-internal-call guarantees.

## Verification

```text
python verify.py /path/to/luau
python analyze_recording.py /path/to/session.jsonl
```

The verifier uses one bounded Luau subprocess against the actual embedded backend. It covers event streams, nil/false/yield/error forwarding, namecall metadata restoration, later-cached functions, privacy/cycles, short stuns/animation endings, coverage/rate limits, Stop/restart/foreign-owner cleanup, respawn,8000+frames, disk failures and silent-large-append regression. The analyzer streams JSONL, summarizes outgoing traffic and recovery timings, and reads the small matching manifest.

A rejected initial direct-native-hook prototype was not published. The replacement's10second live observer test recorded601frames/11outgoing calls without capture/I/O/encoding errors or dropped rows, around59-60FPS. It did not observe an attack from the reference hub or a real stun, and its cached-call proxy execution is fixture-verified rather than proven by those11live calls. Compatibility with every hub/executor is not established.