---
title: Arduino Serial Controller for Godot
---

# Building an Arduino Serial Controller for Godot

Welcome! This tutorial walks you through building a small physical controller with an
Arduino and connecting it to a game running in **Godot 4**. By the end you will have a
real, working system where pressing a button or turning a knob on real hardware changes
what happens on screen.

This is the exact technology used by my senior project, **Virelune**, a two-player
dungeon game controlled by custom physical controllers. The small controller you build
here is the same concept scaled down to something you can finish in an afternoon.

## What you will build

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

- A **push button** (digital input) that makes a player jump.
- A **potentiometer** (analog input) that controls movement speed.
- An Arduino program that sends simple text messages over USB, like `BUTTON:1` and
  `POT:512`.
- A Godot project that reads those messages and uses them in a mini 3D game.

## Tutorial structure

| # | Page | What it covers |
|---|------|----------------|
| 1 | [Introduction](01-introduction.md) | What you will learn, who it is for, prerequisites |
| 2 | [Arduino Setup](02-arduino-setup.md) | What serial is, wiring the button and potentiometer |
| 3 | [Sending Serial Data](03-sending-serial-data.md) | The Arduino program and the message protocol |
| 4 | [Connecting Godot](04-connecting-godot.md) | Installing the serial library and opening the port |
| 5 | [Reading Controller Input](05-reading-controller-input.md) | Receiving and parsing messages in GDScript |
| 6 | [Using Input in a Game](06-using-input-in-a-game.md) | Making the hardware control a mini game |
| 7 | [Practice](07-practice.md) | Two exercises to extend what you built |
| 8 | [Conclusion](08-conclusion.md) | Summary and links to official documentation |

**Start with [Part 1: Introduction](01-introduction.md).**

## The short version

If you want the whole system in one glance, this is the path data takes:

```text
physical input -> serial message -> Godot receives message
             -> GDScript interprets message -> game responds
```

Each section below explains one step of that path in detail, with complete code and
step-by-step instructions.