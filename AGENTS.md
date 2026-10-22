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
