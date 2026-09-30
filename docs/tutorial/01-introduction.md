---
title: Introduction
---

# 1. Introduction

## What this tutorial teaches

This tutorial shows you how to build a **physical game controller** and use it to play a
game on your computer. The controller is built from an **Arduino** board, one push
button, and one potentiometer (a knob). The button and the knob send information to a
**Godot 4** game over a **USB serial connection**, and the game responds to that
information in real time.

It is a smaller version of the controller technology used in my senior project,
**Virelune**. Virelune is a two-player dungeon game where each player uses a custom
physical controller instead of a keyboard. Everything you learn here — reading buttons,
reading a knob, sending data over serial, and making a game react to that data — is the
same pipeline Virelune uses, just with more parts.

## What you will build

By the end of this tutorial you will have:

1. An **Arduino Uno** wired to one push button and one potentiometer.
2. An Arduino program that sends readable messages like `BUTTON:1` and `POT:512` over
   the USB cable.
3. A Godot project that reads those messages.
4. A tiny 3D game where:
   - pressing the button makes a player **jump**, and
   - turning the knob controls the player's **movement speed**.

You will be able to watch the player jump and change speed using the physical hardware in
your hand. That is the whole point: real hardware, controlling a real game.

## Learning objectives

After completing this tutorial you will be able to:

- Explain what serial communication is and why a USB cable can carry it.
- Wire a push button and a potentiometer to an Arduino.
- Read a digital input with `digitalRead()` and an analog input with `analogRead()`.
- Send text data from an Arduino with the `Serial` library.
- Design a simple, readable text protocol for talking between hardware and a game.
- Install the **GdSerial** addon in a Godot project.
- Open a serial port in Godot with `GdSerialManager`, using the correct port name and
  baud rate.
- Receive and parse serial messages in GDScript.
- Use those parsed values to control objects in a game.

## Target audience

This tutorial is written for **beginners**. You do not need to have used Arduino or Godot
before. You should be comfortable reading code and willing to follow instructions step by
step.

A few things are helpful to know before you start, but each one is also explained when it
first appears in the tutorial:

- What a *variable* and a *function* are (in any programming language).
- How to plug things into a breadboard (a quick guide is included in Part 2).

## Prerequisites

- **Basic programming familiarity.** You do not need to know Arduino or Godot, but you
  should have written at least a little code somewhere.
- **No electronics experience required.** Wiring instructions are given in detail.
- **A little patience.** Serial ports, drivers, and first-time setups occasionally need a
  restart or two. That is normal.

## Required hardware

| Item | Notes |
|------|-------|
| Arduino Uno (or compatible) | A board with an onboard USB-to-serial chip |
| USB cable for the Arduino | Usually A to B, like a printer cable |
| 1 push button | Any momentary push button works |
| 1 potentiometer | A 10 kΩ rotary potentiometer is typical |
| 1 breadboard | For connecting things without soldering |
| Jumper wires | A handful of male-to-male wires |
| A computer | Windows, macOS, or Linux |

## Required software

| Software | Where to get it |
|----------|-----------------|
| Arduino IDE (2.x) | [arduino.cc/en/software](https://www.arduino.cc/en/software) |
| Godot 4 (4.4 or newer) | [godotengine.org/download](https://godotengine.org/download/windows/) |
| The GdSerial addon for Godot | Instructions in [Part 4](04-connecting-godot.md) |

> **Note:** The serial approach in this tutorial uses **Godot 4.4+** features. If your
> Godot version is older, update it before starting.

## How the tutorial is organized

Each part builds on the previous one:

| # | Page | What you will do |
|---|------|------------------|
| 1 | Introduction | (You are here) |
| 2 | [Arduino Setup](02-arduino-setup.md) | Understand serial, wire the hardware |
| 3 | [Sending Serial Data](03-sending-serial-data.md) | Program the Arduino and test it |
| 4 | [Connecting Godot](04-connecting-godot.md) | Add the serial library and open the port |
| 5 | [Reading Controller Input](05-reading-controller-input.md) | Parse the incoming messages |
| 6 | [Using Input in a Game](06-using-input-in-a-game.md) | Make the button and knob control a game |
| 7 | [Practice](07-practice.md) | Two exercises to extend your controller |
| 8 | [Conclusion](08-conclusion.md) | Summary and official documentation links |

## Why this matters for Virelune

Virelune is a game where two players explore a dungeon together, and each player uses a
physical controller they hold in their hands. The controllers read buttons and joysticks,
send the data over serial, and the game turns that data into character actions.

The button-and-knob controller in this tutorial is a deliberately tiny version of that
idea. If you can make a button make a character jump, you already understand the core of
how Virelune's controllers work. The only difference in the real project is more inputs,
a bigger protocol, and two players instead of one.

Ready? Let's start by understanding **serial communication** and wiring up the hardware in
[Part 2: Arduino Setup](02-arduino-setup.md).

---

**Next:** [2. Arduino Setup](02-arduino-setup.md)