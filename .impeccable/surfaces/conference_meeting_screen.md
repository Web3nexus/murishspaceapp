# Surface brief — conference_meeting_screen.dart

Scope: the instant-meeting screen (pre-join stage and connected room stage), all device classes, both orientations, light and dark. Visitor mode: **Operate** — a host running a live room, with an audience operating the same surface.

Audience: creator and vendor hosts; guests who join, chat, react and gift. Job: keep the room live and engaged. Action: go live from the pre-join stage; mute, camera, raise hand, gift, chat, leave in the room. Proof/content: the room's real state — who is here, who is speaking, how long it has been live. Constraints: every current feature keeps working; Material 3 structure and controls; 48dp minimum targets; holds on phones and tablets, portrait and landscape.

## Direction contract

THESIS: a live room is a broadcast, so the room says so out loud. It refuses the silent-video-call default where nothing on screen admits the room is live, and it refuses to let a control or a colour exist that carries no state.

OWN-WORLD: navy ink ground tinted from the existing token navy — `#0B1626` room ground, `#0F1A2B` elevated chrome, `#16233A` panel — with brand blue `#007AFF` as the single action colour, and signal amber `#FF9F0A` reserved exclusively for live state (speaking, hand raised, tally). Red `#FF3B30` stays destructive/muted, green `#34C759` stays connected. Type is the Material scale with tracked uppercase micro-labels (0.6sp tracking) on controls and slates. Density is compact broadcast: 8dp rhythm, 48dp touch targets, a 64dp dock. Recognisable with all content removed by the tally rail alone.

STORY: the host opens the room and reads its truth in one glance — live or not, how long, who is speaking, who has a hand up. Guests see the same rail and understand they are inside a broadcast, not a call. Gifts and chat are first-class room activity, never chrome.

FIRST VIEWPORT (connected room): a 3pt tally rail across the top of the stage, carrying the live dot, the elapsed clock, the participant count and the connection state, amber and pulsing while the local participant speaks; below it the video tiles edge-to-edge with the host tile wearing a matching tally border and a HOST slate; the chat panel slides over the stage from the right on phones (bottom sheet on narrow) as translucent elevated chrome; the dock floats at the bottom as a pill of six controls, each an icon over a tracked uppercase micro-label, active states coloured by state not decoration.

FORM: native Flutter, Material 3 structure and components, brand themed through the existing `DesignTokens` file. Seed key: not available — `concept-seed` is absent from this engine build, so the direction was selected through the structured question tool and named `on-air-desk`.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance.

## Memorable moment

The tally rail lighting amber and pulsing with the host's own voice — the room admitting out loud that it is on air.

## Unresolved decisions

- Whether the gift ticker idea (declined challenger) returns as a future surface elsewhere in the app.
- Tablet two-column composition is composed from available width in this build and is not yet documented as a system rule.
