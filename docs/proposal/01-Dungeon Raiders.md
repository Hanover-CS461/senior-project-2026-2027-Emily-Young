---
---
# Draft — Custom Controller + Real Game

**Working names:** TwinArcade · Custom Stick · Input/Output

**One-liner (10 words):** "Build your own controller — and the real game it plays."

**Problem / utility:** Keyboards and mice are generic. A purpose-built controller makes a game tactile and personal — and proves the whole chain: hardware → protocol → game.

**Users:** Me (demo day), classmates, teacher/visitors. Real world: arcade/controller hobbyists.

**Similar products:** HORI/8BitDo arcade sticks, Makey Makey, Nintendo Labo.
**Why different:** Those are a controller OR a game. This is both — custom controller, my own serial protocol (dead zones, calibration), and a real game built to need it.

**Draft features:**
- Arduino controller: joystick + buttons (wheel, flight stick, or panel) — a Leonardo/Pro Micro could fake a native gamepad, but we keep serial for the protocol story
- Custom serial protocol with calibration / dead-zone handling
- One polished game — engine: **Godot recommended** (GDScript ≈ Python, free, light on laptops); Unity = heavier C# option, not needed; Python/Pygame = scope-cut fallback
- Gameplay that genuinely needs the controller, not a reskinned keyboard game

**What you learn:** C++ firmware, a game engine, and a communication protocol you designed.

**Feasibility / risks:**
- Medium risk — two halves to finish; scope to ONE game (main risk = game scope creep)
- Hardware: broken wires / USB quirks → cheap parts, test early
- Scope-cut: drop the controller, same game with keyboard — zero hardware risk

**Before Thursday:** pick the controller form (wheel / stick / panel) + game genre.
