---
title: Conclusion
---

# 8. Conclusion

You made it. You built a physical controller, connected it to a Godot game over USB
serial, and made the hardware move a real game character. Let's review what you learned
and where to go next.

## What you built

The complete system looks like this:

```text
Arduino button / potentiometer
              |
              v
       Arduino program
              |
              v
     USB serial connection
              |
              v
        Godot serial library
              |
              v
      GDScript receives data
              |
              v
    Game responds to input
```

You should now have:

1. An Arduino wired to one button and one potentiometer.
2. An Arduino program sending `BUTTON:1`, `BUTTON:0`, and `POT:512` style messages.
3. A Godot project using `GdSerialManager` to read those messages.
4. A mini game where the button jumps and the knob controls speed.

## What you learned

### Arduino side

- **Serial communication** sends data one bit at a time, and the Arduino's USB chip lets
  the same cable carry power and data.
- **Digital input** with `digitalRead()` and `INPUT_PULLUP` — reading a button as
  `HIGH`/`LOW`.
- **Analog input** with `analogRead()` — reading the potentiometer as a range from 0 to
  1023.
- The **`Serial` library** — `begin()`, `print()`, `println()`, and newline-terminated
  messages.

### Godot side

- Installing the **GdSerial** addon and enabling it in Project Settings.
- Creating a **`GdSerialManager`** and opening a port with `open(port, baud, timeout, mode)`.
- **Baud rate** must match on both sides.
- **Line-buffered** mode hands you one complete message at a time.
- **Polling** with `manager.poll_events()` in `_process()`.
- Receiving a **`PackedByteArray`** and converting it to a **String**.
- **Parsing** messages with `begins_with()`, `split()`, and `int()`.
- Using the parsed values to drive game logic.

## The Virelune connection

This tutorial is a small slice of my senior project, **Virelune**, a two-player dungeon
game controlled by custom physical controllers.

The button-and-knob controller you built is the same idea at a smaller scale:

- **Reading physical inputs** — buttons and knobs today, joysticks and more buttons in
  Virelune.
- **A text protocol** — `BUTTON:1` today, a richer set of labels in Virelune.
- **The same library and API** — `GdSerialManager` is exactly what Virelune uses.
- **Game reacts to hardware** — jumping and speed today, attacking and casting spells in
  Virelune.

If you understand the pipeline you just built, you understand the backbone of the real
project. The only difference is scale: more inputs, a longer protocol, two players, and a
bigger game.

## Where to go next

- Add more inputs (see [Part 7](07-practice.md) for two exercises).
- Build a bigger protocol with messages like `JOY_X:...` and `JOY_Y:...` for a joystick.
- Add a second `GdSerialManager` for a second player, like Virelune.
- Add visual feedback on the Arduino (an LED that lights when a button is pressed).

## See Also

### Arduino official documentation

- [Arduino Serial library reference](https://docs.arduino.cc/language-reference/en/functions/communication/serial/)
- [Serial.begin()](https://docs.arduino.cc/language-reference/en/functions/communication/serial/begin)
- [Serial.println()](https://docs.arduino.cc/language-reference/en/functions/communication/serial/println)
- [digitalRead()](https://docs.arduino.cc/language-reference/en/functions/digital-io/digitalread)
- [analogRead()](https://docs.arduino.cc/language-reference/en/functions/analog-io/analogRead)
- [pinMode() and INPUT_PULLUP](https://docs.arduino.cc/language-reference/en/variables/constants/inputOutputPullup)
- [Built-in examples: Digital Read Serial](https://docs.arduino.cc/built-in-examples/basics/DigitalReadSerial)
- [Built-in examples: Analog Read Serial](https://docs.arduino.cc/built-in-examples/basics/AnalogReadSerial)
- [Built-in examples: InputPullupSerial](https://docs.arduino.cc/built-in-examples/digital/InputPullupSerial)

### Godot official documentation

- [Godot documentation home](https://docs.godotengine.org/en/stable/index.html)
- [GDScript reference](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html)
- [Your first 3D game](https://docs.godotengine.org/en/stable/getting_started/first_3d_game/index.html)
- [CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html#class-characterbody3d)
- [Input handling](https://docs.godotengine.org/en/stable/tutorials/inputs/index.html)

### GdSerial library

- [GdSerial GitHub repository](https://github.com/SujithChristopher/gdserial)
- [GdSerial releases](https://github.com/SujithChristopher/gdserial/releases)

### The tutorial

- [Table of contents](index.md)
- [Back to the start](01-introduction.md)

Thanks for following along. Go build a controller of your own — and maybe you'll end up
with a Virelune of your own too.

---

**Previous:** [7. Practice](07-practice.md)