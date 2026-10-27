# UI convention
All windows, tabs and standalone utilities in this project use the Umbrella
style by default: #151515 main/sidebar, #1C1C1C surfaces, #242424 elements,
#3A3A3A borders, #9B1E28 red accent, #EEEEEE text; rounded sections/controls.
Never substitute generic Dark, bright-red backgrounds or a different design
without an explicit user request. Default show/hide bind is Right Shift;
preserve an explicitly configured custom bind. Keep standalone namespaces,
GUI ownership, settings paths and cleanup isolated from other scripts.
Do not publish recorded coordinates/account data. Public publication permission
covers this recorder only, not private UmbrellaCat/Boundless runtime.

Disable automatic localization on every UI root/text object. Use real full-width
TextBoxes, never place editable text inside a clickable Button wrapper. Match
compact32px controls, 40px section headers and8px section corners; avoid pill
geometry or oversized default WindUI blocks. Verify input hit areas explicitly.

# Passive wide recording contract
Preserve the existing standalone window and public main.lua entry. Default startup begins local streaming, optional CoordinateRecorderAutoStart=false keeps manual start. No duration/sample cap; rebind characters without stopping. Keep bounded queues, append-only JSONL, durable sequence numbers, visible loss/I/O counters and bounded final teardown retries. Never accumulate the entire session or rewrite it per frame. Keep snapshots and marker/notes controls.
No global function/loadstring/namecall hooks, outbound interception, gameplay writes or native callback replacement. Inbound listeners are scoped to relevant Events names and redact arbitrary strings/unapproved fields. Recordings, keys, captures and account data never enter commits. Verify actual backend (verify.py), compile main.lua, preserve clean Git state, push only intended source and verify the public URL's bytes. Live checks may install only this observer and must first verify the current Real client/job; never start the observed hub/gameplay. No claim of full internal-call coverage or extracted source.

Real live observation: appendfile silently dropped64KiB/256KiB calls while8KiB worked. Keep append calls <=8192bytes with safe UTF-8 boundaries; verify the first batch by readback and expose appendVerified. Include the silent-large-append regression before release.

Extended observations use native Tool signals, bounded nearest-NPC HP/state listeners and sampled animation/state data, never claim attack attribution from HP alone or coverage of direct hub remote calls. Preserve 64 tool subscriptions per character/12 concurrent NPC watches, rebind/Stop cleanup, damage episode IDs, 0.2-second measured path windows and PlaneVelocity/attachment data. Do not add a global outgoing-call hook to obtain attack attempts. No persistent Python helpers; verifier runs one bounded Luau subprocess only.
