---
layout: default
title: Virelune
---

# Virelune

> A two-player cooperative dungeon-crawling game controlled by custom physical controllers.

## Project Overview

**Virelune** is a two-player cooperative dungeon-crawling game designed around custom-built physical controllers. Players work together to explore a dungeon, fight enemies, solve simple environmental challenges, and defeat a final boss.

The project combines **game development, hardware integration, human-computer interaction, and software engineering** into one system. Rather than using traditional keyboards or controllers, each player will use a custom physical controller connected to an Arduino-compatible microcontroller.

The game will be developed in **Godot** and designed for local two-player cooperative play on the same computer. The goal is to create a small but polished playable prototype that demonstrates the complete process from physical input to in-game action.

## Main Features

* **Two-player local cooperative gameplay**
* **Custom physical controllers** for each player
* **Joystick and button-based controls**
* **Arduino-compatible microcontrollers** for controller input
* **Serial communication** between the controllers and computer
* **Character-specific abilities and controls**
* **Dungeon exploration**
* **Enemy combat**
* **Simple environmental puzzles and interactions**
* **Final boss encounter**
* **Health and player status**
* **Basic user interface**
* **Custom game visuals and sound**

## Comparable Solutions

### Minecraft Dungeons

Minecraft Dungeons [1] is a cooperative dungeon-crawling game that provides the primary gameplay inspiration for Virelune. It features dungeon exploration, real-time combat, enemies, and boss encounters.

Virelune will use a much smaller scope, focusing on one polished dungeon and emphasizing custom physical controllers rather than inventory systems, extensive character progression, or multiple worlds.

### Nintendo Labo

Nintendo Labo [6] demonstrates how physical interfaces can become part of a game's interaction model. Its use of custom-built physical accessories is relevant to Virelune because the physical controller is intended to be an important part of the gameplay experience rather than simply replacing a keyboard.

### Makey Makey

Makey Makey [7] demonstrates how physical objects can be converted into computer input. Virelune builds on this general concept by creating purpose-built controllers specifically designed for the game's characters and mechanics.

## Technologies

### Godot

Virelune will be developed using **Godot** [2], an open-source game engine supporting both 2D and 3D development. Godot provides the tools needed for scenes, physics, input handling [3], animation, audio, UI, and game logic.

Godot was selected instead of Unity because it is lightweight, open-source, and well suited to the relatively small scope of this project.

### GDScript

The game's gameplay logic will primarily be written in **GDScript** [10], Godot's scripting language. Its syntax is similar to Python, which makes it a reasonable choice given my existing programming experience.

GDScript will be used for player movement, combat, abilities, enemy behavior, interactions, game state, and controller input.

### Arduino

Each custom controller will use an **Arduino-compatible microcontroller** [4] to read physical inputs such as joysticks and buttons.

The controller hardware is based on concepts I have already worked with, so Arduino itself is not expected to be a major new learning area for this project.

### Serial Communication

The controllers will communicate with the computer using **serial communication** [5].

A structured protocol will allow the game to receive information such as:

* Controller identification
* Joystick position
* Button states
* Special inputs
* Calibration information

The game will then translate these inputs into player actions.

### Local Cooperative Multiplayer

Virelune will support two players on the same computer. Each player will have their own controller and character.

Because the players will share the same game instance, online networking is not required. This keeps the project focused on the interaction between the custom hardware and the game.

### Libraries

Virelune will rely on existing libraries wherever practical so that common functionality does not need to be hand-rolled.

Godot ships with built-in modules for physics, animation, audio, UI, and scene management [2], [3], so these systems are used directly rather than reimplemented.

For reading serial data inside Godot, a community serial-port addon (such as the GDSeriport addon or a similar maintained plugin) is the primary option. If no addon proves reliable with the chosen board, the fallback is to implement the serial reading layer directly in GDScript.

On the Arduino side, the built-in `Serial` library handles USB-to-serial communication between the board and the computer [5], and Arduino input libraries provide joystick reading and button debouncing so the controller firmware does not have to reimplement these basics.

## System Overview

The major components of Virelune will work together as follows:

```text
┌──────────────────────┐
│   Player 1 Controller│
│   Joystick + Buttons │
└──────────┬───────────┘
           │
           │ Serial
           ▼
┌──────────────────────┐
│                      │
│      Computer        │
│                      │
│       Godot          │
│                      │
│  ┌────────────────┐  │
│  │ Virelune Game  │  │
│  │                │  │
│  │ Player 1       │  │
│  │ Player 2       │  │
│  │ Enemies        │  │
│  │ Dungeon        │  │
│  │ Boss           │  │
│  └────────────────┘  │
│                      │
└──────────┬───────────┘
           │
           │ Serial
           ▼
┌──────────────────────┐
│   Player 2 Controller│
│   Joystick + Buttons │
└──────────────────────┘
```

The controllers provide physical input, the computer receives and interprets that input, and Godot converts it into actions within Virelune.

## Technology Alternatives

### Godot vs. Unity

**Godot** was selected because it is open-source, lightweight, and appropriate for the project's limited development time. Its GDScript language also has similarities to Python.

**Unity** was considered because it is a widely used game engine with extensive documentation and resources. However, Godot better fits the project's goal of keeping the development environment lightweight and focusing on the custom hardware integration.

### GDScript vs. C#

Godot supports both GDScript and C#. C# was considered because of its widespread use in software development and game development.

GDScript was selected because its Python-like syntax is familiar and because it integrates directly with Godot's game-development workflow.

### Custom Serial Protocol vs. Standard Gamepad

A standard USB gamepad or a commercial arcade stick [8], [9] would be simpler to integrate, but it would not demonstrate the hardware-software integration that is central to this project.

A custom serial protocol allows the controllers to communicate their own inputs and gives the project more control over how physical actions are interpreted by the game.

## New Concepts and Technologies to Learn

Although I already have experience with programming and Arduino-based input, Virelune introduces several areas that I will need to learn.

### Godot Game Development

I will need to learn Godot's scene system, nodes, resources, physics, animation, UI, audio, and game-state management.

### GDScript

Although GDScript has similarities to Python, I will need to learn Godot-specific programming patterns and how GDScript interacts with Godot's scene and node architecture.

### Game Architecture

I will need to learn how to organize a larger interactive application into reusable systems for players, enemies, combat, abilities, controllers, and game states.

### Game Design and Balancing

Creating a cooperative game requires designing mechanics that encourage players to work together. The two controllers and character abilities should provide meaningful differences without making either player unnecessary.

### Hardware-to-Game Integration

The Arduino hardware itself is familiar, but connecting the physical controller to a complete game introduces new challenges involving serial communication, input processing, calibration, timing, and translating physical actions into gameplay.

## Development Scope

The project will prioritize a **small, polished prototype** over a large amount of content.

## Project Challenges

The primary technical challenge will be integrating the custom controllers with the Godot game while maintaining responsive and reliable input.

Another challenge will be designing cooperative mechanics that make both players useful. The controllers should feel like a meaningful part of the game rather than simply replacing a keyboard.

The limited development timeline also requires careful scope management. The project will focus on one dungeon, a limited number of enemies, a small number of abilities, and one final boss rather than attempting to create a large commercial-scale game.

## References

[1] Mojang Studios, "Minecraft Dungeons." Accessed: Sep. 2, 2026. [Online]. Available: https://www.minecraft.net/en-us/about-dungeons

[2] Godot Engine, "Godot Engine." Accessed: Sep. 2, 2026. [Online]. Available: https://godotengine.org/

[3] Godot Engine, "InputEvent and Input Documentation." Accessed: Sep. 2, 2026. [Online]. Available: https://docs.godotengine.org/en/stable/tutorials/inputs/

[4] Arduino, "Arduino Documentation." Accessed: Sep. 2, 2026. [Online]. Available: https://docs.arduino.cc/

[5] Arduino, "Serial Communication." Accessed: Sep. 2, 2026. [Online]. Available: https://docs.arduino.cc/language-reference/en/functions/communication/serial/

[6] Nintendo, "Nintendo Labo." Accessed: Sep. 2, 2026. [Online]. Available: https://www.nintendo.com/us/gaming-systems/switch/nintendo-labo/

[7] Makey Makey, "Makey Makey." Accessed: Sep. 2, 2026. [Online]. Available: https://makeymakey.com/

[8] HORI, "Arcade Controllers." Accessed: Sep. 2, 2026. [Online]. Available: https://stores.horiusa.com/

[9] 8BitDo, "Arcade Stick." Accessed: Sep. 2, 2026. [Online]. Available: https://www.8bitdo.com/

[10] Godot Engine, "GDScript Documentation." Accessed: Sep. 2, 2026. [Online]. Available: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/