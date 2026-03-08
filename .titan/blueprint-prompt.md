# App Blueprint — AI Test Generation Context

Generated: 2026-03-07T21:01:37.906791
Screens: 7 | Transitions: 11 | Sessions Analyzed: 5

## Navigation Map

APP TERRAIN MAP
===============
Screens: 7 | Transitions: 11 | Sessions analyzed: 5
Auth-protected: 0 | Public: 7

SCREEN: Home (Quest List) (/)
AUTH: not required
OBSERVED: 15 times
EXITS: → /quest/:id (tap "View Quest"), → /settings (tap "Settings"), → /shade-demo (tap "Shade Demo"), → /enterprise (tap "Enterprise"), → /form-demo (tap "Forms")

SCREEN: Quest Detail (/quest/:id)
AUTH: not required
OBSERVED: 12 times
EXITS: → / (back), → /quest/:id/edit (tap "Edit")

SCREEN: Quest Edit (/quest/:id/edit)
AUTH: not required
OBSERVED: 4 times
EXITS: → /quest/:id (back)

SCREEN: Settings (/settings)
AUTH: not required
OBSERVED: 3 times
EXITS: → / (back)

SCREEN: Shade Demo (/shade-demo)
AUTH: not required
OBSERVED: 5 times
EXITS: → / (back)

SCREEN: Enterprise Demo (/enterprise)
AUTH: not required
OBSERVED: 3 times
EXITS: → / (back)

SCREEN: Scroll & Form Demo (/form-demo)
AUTH: not required
OBSERVED: 2 times

DEAD ENDS: /form-demo

## Dead Ends (1)

- `/form-demo` — 2 visits, no outgoing transitions

## Suggested Test Scenarios (19)

### gauntlet_bedrock_back__

Press back from root screen Home (Quest List)

**Start route:** `/`
**Steps:** 2
**Tags:** gauntlet, navigation, bedrock-back

### gauntlet_eternal_march__

Circular navigation / ↔ /quest/:id (5 cycles)

**Start route:** `/`
**Steps:** 10
**Tags:** gauntlet, navigation, circular

### gauntlet_forgotten_outpost__

Navigate away from Home (Quest List) and back, verify state

**Start route:** `/`
**Steps:** 3
**Tags:** gauntlet, state, stale-screen

### gauntlet_bedrock_back__quest__id

Press back from root screen Quest Detail

**Start route:** `/quest/:id`
**Steps:** 2
**Tags:** gauntlet, navigation, bedrock-back

### gauntlet_eternal_march__quest__id

Circular navigation /quest/:id ↔ / (5 cycles)

**Start route:** `/quest/:id`
**Steps:** 10
**Tags:** gauntlet, navigation, circular

### gauntlet_forgotten_outpost__quest__id

Navigate away from Quest Detail and back, verify state

**Start route:** `/quest/:id`
**Steps:** 3
**Tags:** gauntlet, state, stale-screen

### gauntlet_bedrock_back__quest__id_edit

Press back from root screen Quest Edit

**Start route:** `/quest/:id/edit`
**Steps:** 2
**Tags:** gauntlet, navigation, bedrock-back

### gauntlet_eternal_march__quest__id_edit

Circular navigation /quest/:id/edit ↔ /quest/:id (5 cycles)

**Start route:** `/quest/:id/edit`
**Steps:** 10
**Tags:** gauntlet, navigation, circular

### gauntlet_forgotten_outpost__quest__id_edit

Navigate away from Quest Edit and back, verify state

**Start route:** `/quest/:id/edit`
**Steps:** 3
**Tags:** gauntlet, state, stale-screen

### gauntlet_bedrock_back__settings

Press back from root screen Settings

**Start route:** `/settings`
**Steps:** 2
**Tags:** gauntlet, navigation, bedrock-back

### gauntlet_eternal_march__settings

Circular navigation /settings ↔ / (5 cycles)

**Start route:** `/settings`
**Steps:** 10
**Tags:** gauntlet, navigation, circular

### gauntlet_forgotten_outpost__settings

Navigate away from Settings and back, verify state

**Start route:** `/settings`
**Steps:** 3
**Tags:** gauntlet, state, stale-screen

### gauntlet_bedrock_back__shade_demo

Press back from root screen Shade Demo

**Start route:** `/shade-demo`
**Steps:** 2
**Tags:** gauntlet, navigation, bedrock-back

### gauntlet_eternal_march__shade_demo

Circular navigation /shade-demo ↔ / (5 cycles)

**Start route:** `/shade-demo`
**Steps:** 10
**Tags:** gauntlet, navigation, circular

### gauntlet_forgotten_outpost__shade_demo

Navigate away from Shade Demo and back, verify state

**Start route:** `/shade-demo`
**Steps:** 3
**Tags:** gauntlet, state, stale-screen

### gauntlet_bedrock_back__enterprise

Press back from root screen Enterprise Demo

**Start route:** `/enterprise`
**Steps:** 2
**Tags:** gauntlet, navigation, bedrock-back

### gauntlet_eternal_march__enterprise

Circular navigation /enterprise ↔ / (5 cycles)

**Start route:** `/enterprise`
**Steps:** 10
**Tags:** gauntlet, navigation, circular

### gauntlet_forgotten_outpost__enterprise

Navigate away from Enterprise Demo and back, verify state

**Start route:** `/enterprise`
**Steps:** 3
**Tags:** gauntlet, state, stale-screen

### gauntlet_bedrock_back__form_demo

Press back from root screen Scroll & Form Demo

**Start route:** `/form-demo`
**Steps:** 2
**Tags:** gauntlet, navigation, bedrock-back

## Known Route Patterns

- `/quest/:id`
- `/quest/:id/edit`

