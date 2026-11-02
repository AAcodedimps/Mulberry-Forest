# Mulberry Forest: credits

## Game
Design, code and art: made for Mulberry Forest. Everything you see is drawn in code with
Godot's `_draw()`; there are no image files.

Engine: [Godot Engine](https://godotengine.org) 4.7 (MIT licence).
Text uses Godot's built-in default font, which ships with the engine. Its licence is listed
in the Godot editor under Help > About > Third-party Licences.

## Sound effects and music
**No outside sound or music files are used.** Every sound effect and both music loops were
generated from scratch for this game by `tools/make_audio.py`, using sine waves, filtered noise
and a simple reverb. There are no recordings, samples or loops from anywhere else, so there is
nothing to credit or licence. You can treat them as your own (CC0 / public domain).

| File in `audio/` | What it is |
|---|---|
| `jump.res`, `land.res` | jumping and landing |
| `pickup_stone.res`, `pickup_power.res`, `pickup_cure.res` | picking up a stone, a Forest Power, Wild Berries |
| `throw.res`, `ghost_hit.res` | throwing a stone, a stone hitting a ghost (or a hive) |
| `ghost_rise.res`, `mischief_rise.res`, `caught.res` | a killer / mischief ghost rising, being caught |
| `squash.res` | squashing a killer ghost |
| `trip.res`, `smash.res`, `fall.res` | tripping on a trunk, smashing it with Strength Fig, falling into a hole |
| `tree_shake.res`, `berry.res` | shaking a mulberry tree, a berry dropping into the basket |
| `bees.res` | bees buzzing (loop) |
| `gate_open.res`, `gate_deny.res` | the stone gate opening, and refusing you |
| `shield.res` | Bark Shield blocking a hit |
| `ui_click.res`, `win.res` | menu buttons, escaping the forest |
| `music_calm.res` | calm forest music (29-second loop) |
| `music_tense.res` | tense layer that fades in when a killer ghost is close (same length, plays in step) |

The flood's rushing-water warning is also generated, in code, inside `scenes/hurdles/flood.gd`.

To change a sound: edit `tools/make_audio.py`, run `python tools/make_audio.py tools/audio_raw`,
then `godot --headless --path . -s tools/raw_to_res.gd`. You need Python with numpy and scipy.
