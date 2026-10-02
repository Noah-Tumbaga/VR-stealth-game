# Shadowveil: a VR stealth assassination game (Godot 4.3)

You are a silent assassin who works with shadow magic. Get into **Vane Manor** at midnight,
kill **Lord Aldric Vane**, and slip away to the river without anyone seeing you.

Everything is generated procedurally at startup: the detailed character models, the PBR
materials and textures, the whole map, the particles and even the sound effects. The project
has no imported art or audio assets.

| | |
|---|---|
| ![Guard](docs/guard.png) | ![Lord Vane](docs/lord.png) |
| ![Manor](docs/manor.png) | ![Garden](docs/garden.png) |

*(Screenshots come from the software-rendered Compatibility backend. The real Forward+
renderer adds volumetric fog, SSAO and better shadows.)*

## Running

1. Open the folder in **Godot 4.3+** (standard build; OpenXR is built in).
2. **VR:** start your OpenXR runtime (SteamVR, Oculus/Meta Link, WMR, Monado…) and press Play.
   The game detects the headset automatically.
3. **No headset:** the game falls back to mouse and keyboard. Pass `--desktop` after `--`
   to force this mode even when a headset is connected.

## How stealth works

- **Light is your enemy.** The game measures your visibility from real light sources
  (torches, braziers, lamp posts, candles, chandeliers, guard lanterns, moonlight blocked by
  roofs). Watch the **light gem** on your left wrist (VR) or the HUD gem (desktop).
- **Crouching** (physically, or with the right stick down) makes you harder to see and much
  quieter. You are almost invisible while crouched in **bushes, hay piles and flower bushes**.
- **Movement makes noise guards can hear**, even though you won't hear your own footsteps.
  Sprinting is loud, walking is moderate and crouching is nearly silent. Walls muffle sound.
- **Guards** have a vision cone with line-of-sight checks and a close-range "sixth sense".
  Their awareness fills up over time: `?` means suspicious, and they come to investigate.
  Guards who find a **body** sound the alarm. Guards who find a **sleeper** wake them up.

### Getting spotted

When a guard's awareness fills, he freezes and starts to shout. A flashing orange `!`
appears over him, you hear a sting and your controllers buzz. You then have
**0.85 seconds** to silence him with a throat kill, a crossbow headshot or a Blinding Hex.
If you miss that window:

- The **alarm** rings for 90 seconds. Every guard's detection speeds up and later
  sightings skip the reaction window.
- **Three gate sergeants** come through the gate and hunt your last known position.
- **Combat is lethal.** Guards lunge into their swings and hit for **40 damage**, so three
  hits kill you. Each hit staggers you to a crawl, and you don't heal while the alarm is up.
  They run faster than you can sprint. Alerted guards parry about 70 % of blows and need
  about 4 body wounds to kill. You can't win a fair fight. Break line of sight and hide, or
  blind them.

## Killing

### The dagger

- The dagger rests in a **sheath on your chest**. In VR, reach to it with your right hand
  and squeeze grip to draw it. Let go of grip and it goes back in the sheath.
- **Only the throat kills.** Either drag the blade across the neck or stab into it. A
  guard can be killed this way if he's unaware, seen from behind, in his reaction window,
  blinded, asleep or held.
- **Hitting the body only wounds.** The guard screams and fights you right away.
- **Cover his mouth.** From behind, grab his face with your left hand (left grip). He
  struggles, muffled, for about 1.8 seconds. If you open his throat while you hold him, the
  kill is **silent** and you lower him quietly to the ground. If you hesitate, he breaks
  free and raises the alarm.
- If you kill him **without** covering his mouth, he dies with a choked cry. Guards within
  about 11 m come running and find the body.
- A guard who is fighting you and facing you **parries** throat strikes, unless you catch
  him while his sword is raised.

### The hand crossbow

- The crossbow is **holstered on your right hip**. Draw it like the dagger. The right
  trigger fires along the crossbow, and the glowing rune sights help you aim in the dark.
- A **headshot kills silently**. A body shot only wounds, and the guard screams.
- A bolt that misses thunks into the wall, and nearby guards come to look. You can use
  this as a lure.
- The crossbow cranks itself back in 2.4 seconds. You carry **8 bolts**.

## Shadow magic (left hand)

Each spell is powerful, but only for stealth:

| # | Spell | Mana | Effect |
|---|-------|------|--------|
| 1 | **Blinding Hex** | 30 | A burst of searing shadow-light. Every guard in the burst goes blind and **panics**: they claw at their eyes and stumble around screaming. The scream draws other guards to *them*, not to you. Blind guards can be killed face to face. |
| 2 | **Slumber** | 35 | Puts an **unaware** mind into deep sleep for 40 s. It **fails on alerted guards**. A sleeper can be killed or left alone, but another guard may wake them. |
| 3 | **Echo Lure** | 15 | Throws a phantom clatter of pots and pans. Nearby guards go to investigate the spot. |
| 4 | **Snuff** | 10 | Puts out a torch, brazier, candle or lamp that you point at, so you can make your own shadows. |
| 5 | **Shadow Step** | 25 | A silent blink of up to 13 m. Aim at the top edge of a wall to mount ledges, roofs and the stable rooftop. |
| 6 | **Shroud** | 40 | Living darkness makes you nearly invisible for 10 s. Attacking breaks it. |

Mana regenerates slowly, and so does health once you are out of combat.

## Controls

### VR (OpenXR default action map)
| Input | Action |
|---|---|
| Left stick | Smooth locomotion (head-relative). Click and hold while moving to sprint. |
| Right stick left/right | Snap turn 40° |
| Right stick down | Toggle crouch (you can also physically crouch) |
| Right grip at your chest / right hip | Draw the dagger / the crossbow (release grip to put it away) |
| **Swing your right hand** | Dagger: slash across or stab into the **throat** |
| Right trigger | Fire the crossbow |
| Left grip on a guard's face | Cover his mouth and restrain him |
| Left trigger (half / full) | Aim the spell (shows a beam and target marker) / cast |
| Left Y/B · X/A | Next / previous spell |
| Left menu | Show the objective. After the mission ends: restart |

The **left wrist** shows the current spell, a mana bar, a health bar and the light gem.
Haptics pulse when you're spotted, when you kill or get hit, while a held guard struggles, and with your heartbeat as guards grow suspicious.

### Desktop
| Key | Action |
|---|---|
| WASD / mouse | Move / look |
| Shift | Sprint (guards hear it) |
| C or Ctrl | Toggle crouch |
| F / B | Draw or sheathe the dagger / the crossbow |
| V (hold) | Cover the mouth of the guard in front of you |
| LMB | Dagger: aim at the throat (when you're holding a mouth, it slits automatically) · Crossbow: fire |
| RMB (hold → release) | Aim → cast the selected spell |
| 1–6, Q/E, mouse wheel | Select spell |
| H | Show or hide help · Esc releases the mouse · R restarts after the mission ends (Shift+R any time) |

## The test map: Vane Manor

- **South forest:** this is where you start, at a small camp. Pines, rocks and bushes give
  cover. A road runs to the lit **gatehouse**, which two guards watch. The **extraction**
  point is the blue spirit-light on the dock by the river.
- **Collapsed breach** in the south-west wall: the quiet way in.
- **Courtyard:** a well, market stalls, carts, crates, hay, archery butts, a statue of the
  lord and pools of lamp light with dark gaps between them. Two guards patrol here, one with
  a **lantern that lights you up**.
- **Barracks (west):** bunks, a dice table and a weapon rack. One guard sleeps off his watch
  and another wanders in and out.
- **Vane Manor (north):** the great hall has a throne dais, a long feast table, a fireplace,
  a chandelier, pillars, suits of armour and banners. Next to it is the lord's **study**,
  with a desk, bookshelves and a globe. The front door is guarded and lit by braziers. There
  is a **side door to the garden**.
- **Hedge garden (east):** hedges, a gazebo, a fountain, rose bushes and flower beds, patrolled
  by a guard with a lantern.
- **Stable (south-east):** hay piles to hide in, and a **flat roof** you can Shadow Step onto.

**Lord Vane** follows a routine. He holds court at his throne, reads at his study desk,
then walks out of the side door to the gazebo and the fountain before he returns. **Captain
Roderick** shadows him. If the alarm goes up, the lord runs and cowers in his study.

Your end rating depends on alarms, bodies and kills. Kill only the lord, with no alarms, to
earn **SILENT ASSASSIN**.

## Project layout

```
scenes/main.tscn                 entry scene (everything else is built in code)
scripts/main.gd                  XR / desktop bootstrap
scripts/autoload/game_state.gd   noise bus, alarm, light-level queries, objectives, stats
scripts/autoload/sfx.gd          procedural audio synthesis (all SFX + ambience)
scripts/util/mats.gd             procedural PBR materials (noise-generated albedo/normal maps)
scripts/util/geo.gd              primitive-mesh + collision helpers
scripts/npc/humanoid.gd          detailed procedural humanoid model + procedural animation
scripts/npc/guard.gd             guard/target AI (perception, hearing, states, combat)
scripts/player/player.gd         VR + desktop player, locomotion, spells, stealth metrics
scripts/player/weapons.gd        chest sheath, hip holster, throat kills, mouth cover, crossbow
scripts/player/bolt.gd           crossbow bolt
scripts/player/hand_models.gd    gloved hands, dagger, crossbow, sheath, holster, casting orb, wrist display
scripts/magic/spell_projectile.gd
scripts/world/level_builder.gd   the map, lighting, NPC roster, navmesh
scripts/world/props.gd           40+ detailed prop builders
scripts/world/light_source.gd    flickering, snuffable lights
scripts/fx/fx.gd                 particles: blood, smoke, magic bursts
shaders/night_sky.gdshader       starfield + moon sky
tests/                           headless smoke test, patrol soak test, screenshot rig
```

## Tests

```bash
# Gameplay smoke test (28 checks): patrols, the spotted reaction window, alarm and
# reinforcements, throat-only kills, wounding, mouth cover, parries, crossbow headshot
# and body shot, spells, a live desktop takedown, and mission completion.
godot --headless --fixed-fps 60 --path . res://tests/smoke_test.tscn -- --desktop

# 2-minute patrol soak test (reports any guard that gets stuck on geometry)
godot --headless --fixed-fps 60 --path . res://tests/patrol_test.tscn -- --desktop

# Review screenshots (needs a display or xvfb-run)
godot --path . res://tests/screenshots.tscn -- --desktop --out=/tmp/shots
```

## Performance notes

The game targets PC VR with the Forward+ renderer. Volumetric fog is turned off
automatically in VR to keep frame times low. To run on standalone Quest, switch the
renderer to Mobile and lower the number of shadow-casting lights in `level_builder.gd`.
