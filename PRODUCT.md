# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

The same Flutter codebase also ships on iOS and does not adapt its design language per OS.

## Users

Creators and Vendor accounts who host instant meetings, and the audience (fans and buyers) who join them. Confirmed: hosting is reserved for Creator and Vendor accounts; other accounts hit an upgrade gate. Creators and vendors share one screen today — there is no role-specific layout.

## Product Purpose

MurihSpace is a social commerce platform. Instant meetings are its live room: a host opens a room, the audience joins with audio/video, chats, raises hands, reacts and sends gifts. Success on this surface is an engaged room — chat, reactions and gifts — not merely a connected call.

## Operating Context

A LiveKit room with the host's participant identity set to their user id and `"role": "host"` in participant metadata; there is no separate persisted host record on the client, so the host is derived from the room. Meeting signalling and messages arrive over WebSocket alongside the REST meeting endpoints. The screen runs in two stages: a pre-join stage (permissions, device checks, feature badges, upgrade gate) and a connected stage (video tiles, chat panel, control dock, floating reactions, gift animations).

## Capabilities and Constraints

Confirmed on the screen today and required to keep working: pre-join and connecting stages; a video tile grid including a local "You" tile; a chat panel; a control dock with mute, camera, raise hand, gift, chat toggle and leave; floating reaction particles; gift animations; host derivation from participant metadata; and the Creator/Vendor upgrade gate.

Confirmed for the redesign in progress: all of the above keep working — the change is visual, not behavioural. The result must hold on phones and tablets, portrait and landscape.

Confirmed undecided: no role-specific layout exists for creators versus vendors, and none was requested.

## Brand Commitments

The product name is MurihSpace. A single shared token file, `lib/core/design_tokens.dart`, is the brand palette and radius scale for the whole app, and `lib/config/theme.dart` builds the app themes from it. Any redesign of one screen stays inside that shared system rather than inventing a parallel palette.

## Evidence on Hand

The incumbent screen itself: `lib/screens/conference_meeting_screen.dart`. The token and theme sources above. No committed goldens, screenshot fixtures or design documentation exist for this screen; absence of prior visual documentation is not licence to invent product claims.

## Product Principles

- One screen serves both creator and vendor hosts; do not fork the layout by role without a request.
- Chat, reactions and gifts are the product on this surface, not chrome around a video call.
- Behaviour is confirmed product truth: a redesign may change how anything looks, never what it does.
- The screen must hold on phones and tablets, so layout is composed from available width, not fixed pixels.
