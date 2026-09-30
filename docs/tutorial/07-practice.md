---
title: Practice
---

# 7. Practice

You have a working button-and-knob controller. Now it's time to stretch. These two
exercises ask you to **modify and extend** what you built — exactly the kind of change
you'd make when growing this into something like Virelune.

Try each one on your own first. Hints are included after each goal, and a worked hint
appears at the very end if you get truly stuck.

## Exercise 1: Add a second button

### The goal

Add a **second push button** to your controller and make the game react to it. You choose
what it does — for example:

- make the player **spin** while held, or
- make the player **duck** (shrink) while held, or
- make the player **change color** when pressed.

The important thing is that **both** Arduino and Godot must be updated and they must agree
on the new message.

### What you will change

You need to change three places:

1. **Hardware:** wire a second button to a new digital pin.
2. **Arduino:** read that pin and send a new message.
3. **Godot:** parse the new message and use it.

### Hints

**Hardware / Arduino hints**

- Wire the button the same way as the first: one side to `GND`, the other to a free
  digital pin (for example pin 3).
- Add `const int BUTTON2_PIN = 3;` near the top of the Arduino sketch.
- In `setup()`, add `pinMode(BUTTON2_PIN, INPUT_PULLUP);`.
- In `loop()`, copy the button-reading block and change the message label. Call it
  something clear like `BUTTON2:1` and `BUTTON2:0`.

**Godot hints**

- In `_on_data_received`, add another `elif text.begins_with("BUTTON2:")` branch.
- Parse the value the same way (`text.split(":")[1]`) and store it in a new variable, for
  example `var button2_pressed: bool`.
- In `_physics_process`, use `button2_pressed` to do your chosen action — e.g. `rotate_y()`
  or changing `scale`.

### Test

- Upload the updated Arduino sketch and confirm the Serial Monitor shows `BUTTON2:1` /
  `BUTTON2:0`.
- Run the Godot scene and confirm the new action triggers when you press the second
  button.

## Exercise 2: Make the knob control something else

### The goal

The potentiometer already controls forward speed. Give the **analog input a second job** —
use the knob to control **rotation**.

Pick one:

- Make the player **turn left/right** based on the knob position (knob near 0 = turn
  left, near 1023 = turn right, center = straight).
- Make the player **spin continuously**, with the knob controlling *how fast* it spins.

### Hints

- The knob gives you `pot_value`, an integer from 0 to 1023. Its **center** is about 512.
- To get a "turn amount", subtract the center:
  `var turn = pot_value - 512`. This is negative on the left of center and positive on the
  right.
- Scale it down — the raw range is huge. Something like `turn / 1000.0` gives a small,
  usable rotation.
- Rotate the player in `_physics_process` with `rotate_y(turn_amount * _delta)`. The
  `_delta` keeps the rotation rate frame-rate independent.

### Test

- Run the scene. Turning the knob should visibly rotate the player, either steering or
  spinning it at a speed you control.

> **Challenge:** If the rotation replaces forward speed, the player may be harder to
> watch. Try **combining** both: the knob steers *and* you keep speed from something else
> (or re-use the same value cleverly). You are the designer now.

## Before the next part

After finishing both exercises you should feel comfortable with the full loop:

```text
wire hardware -> program Arduino -> send messages -> parse in Godot -> react in game
```

That's the core skill of Virelune's controllers, applied to a much smaller scale. When
you're ready, finish with [Part 8: Conclusion](08-conclusion.md).

---

**Previous:** [6. Using Input in a Game](06-using-input-in-a-game.md) | **Next:** [8. Conclusion](08-conclusion.md)