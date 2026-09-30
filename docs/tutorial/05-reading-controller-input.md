---
title: Reading Controller Input
---

# 5. Reading Controller Input

In [Part 4](04-connecting-godot.md) you saw raw messages printing in Godot's Output panel.
Now we turn those raw strings into **values Godot can use** — numbers and booleans your
game logic can act on.

This part covers:

- The `data_received` callback and its `PackedByteArray` parameter.
- Converting the byte array to a readable `String`.
- Parsing the `BUTTON:` and `POT:` messages.
- Storing the results in variables.

## 5.1 What the callback gives us

When a complete line arrives, GdSerialManager calls this function:

```gdscript
func _on_data_received(port: String, data: PackedByteArray):
    var text = data.get_string_from_utf8().strip_edges()
```

There are two parameters:

- `port` — the name of the serial port the data came from (`"COM5"` in our case). This is
  useful in a project with several controllers, like Virelune.
- `data` — the raw bytes that arrived, as a **`PackedByteArray`**.

### What is a PackedByteArray?

A `PackedByteArray` is simply a list of numbers from 0 to 255 — the raw bytes sent over
the wire. Text, to a computer, is just a sequence of bytes. For example, the message
`BUTTON:1` is really the bytes `66 85 84 84 79 78 58 49`.

We don't want to work with raw byte numbers, so we convert them to a string:

```gdscript
var text = data.get_string_from_utf8()
```

`get_string_from_utf8()` interprets the bytes as **UTF-8 text** and returns a normal
`String`. UTF-8 is just the standard way text is encoded; `BUTTON:1` becomes the string
`"BUTTON:1"`.

### Why `.strip_edges()`?

The Arduino ends each message with a newline (`\n`) and, on Windows, a carriage return
(`\r`) too. `strip_edges()` removes leading and trailing whitespace (including those
hidden newline characters), so `text` is exactly `BUTTON:1` with no leftovers.

> **Note:** A `PackedByteArray` is a built-in Godot type — a tightly packed array of
> bytes. You can learn more in the
> [official Godot documentation](https://docs.godotengine.org/en/stable/classes/class_packedbytearray.html#class-packedbytearray).

## 5.2 The full parsing script

Create a new script called `controller.gd` and paste the following. It reads the serial
port, parses each message, and stores the results in variables that a game can use.

```gdscript
extends Node

var manager: GdSerialManager

# Values we want to expose to the rest of the game.
var button_pressed: bool = false
var pot_value: int = 0

func _ready():
    manager = GdSerialManager.new()
    manager.data_received.connect(_on_data_received)

    if manager.open(
        "COM5",            # <-- change this to your port name
        9600,
        1000,
        GdSerialManager.MODE_LINE_BUFFERED
    ):
        print("Arduino connected!")
    else:
        print("Could not connect to Arduino!")

func _process(_delta):
    manager.poll_events()

func _on_data_received(port: String, data: PackedByteArray):
    var text = data.get_string_from_utf8().strip_edges()

    if text.begins_with("BUTTON:"):
        var value = text.split(":")[1]
        button_pressed = (value == "1")

    elif text.begins_with("POT:"):
        var value = text.split(":")[1]
        pot_value = int(value)
```

## 5.3 How the parsing works

### `text.split(":")`

`split(":")` breaks the string apart wherever a `:` appears and returns an array of
pieces.

```text
"BUTTON:1".split(":")  ->  ["BUTTON", "1"]
"POT:512".split(":")   ->  ["POT", "512"]
```

`[1]` grabs the second piece — the value after the colon.

### `text.begins_with("BUTTON:")`

A quick way to check which kind of message we received. If the text starts with `BUTTON:`,
we know the value is a button state. This is a clean way to route different messages to
different code. See the official
[String documentation](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string-method-begins-with)
for `begins_with()`.

### `button_pressed = (value == "1")`

`value` is a string (`"1"` or `"0"`). Comparing it to the string `"1"` gives a **boolean**
(`true`/`false`), which is what we store. Now the rest of the game can simply check
`controller.button_pressed`.

### `pot_value = int(value)`

`value` is the string `"512"`. `int()` converts it to the number `512` so we can do math
with it (like scaling it to a speed). See the
[int() conversion](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)
in the Godot docs.

## 5.4 Test the parsing

To prove the parsing works, add a quick debug print to the callback:

```gdscript
func _on_data_received(port: String, data: PackedByteArray):
    var text = data.get_string_from_utf8().strip_edges()

    if text.begins_with("BUTTON:"):
        var value = text.split(":")[1]
        button_pressed = (value == "1")
        print("Button pressed: ", button_pressed)

    elif text.begins_with("POT:"):
        var value = text.split(":")[1]
        pot_value = int(value)
        print("Pot value: ", pot_value)
```

Run the scene, press the button, and turn the knob. The Output panel should show
something like:

```text
Arduino connected!
Button pressed: true
Button pressed: false
Pot value: 512
Pot value: 700
```

## 5.5 Understanding the flow

This is the core of the whole tutorial. A message's journey:

```text
physical input          (you press the button / turn the knob)
   -> serial message    (BUTTON:1, POT:512 over USB)
   -> Godot receives    (GdSerialManager emits data_received)
   -> GDScript interprets (split, compare, int())
   -> game responds     (uses button_pressed and pot_value)
```

Right now we stop at "interprets." In the next part we finally make the game **respond**.

## 5.6 Checklist before continuing

- [ ] `button_pressed` is `true` while the button is held and `false` when released.
- [ ] `pot_value` is a number between 0 and 1023 that changes with the knob.

Time to use those values in a real game. Continue to
[Part 6: Using Input in a Game](06-using-input-in-a-game.md).

---

**Previous:** [4. Connecting Godot](04-connecting-godot.md) | **Next:** [6. Using Input in a Game](06-using-input-in-a-game.md)