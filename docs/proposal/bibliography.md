---
---
# Annotated Bibliography — Virelune

## 1. Minecraft Dungeons

**Link:** https://www.minecraft.net/en-us/about-dungeons

**Kind of source:** Primary source. This is the official Minecraft Dungeons website published by Mojang Studios/Microsoft.

**Relation to my app:** Similar/competing game and primary gameplay inspiration.

**Description:**
Minecraft Dungeons is a cooperative action-adventure dungeon crawler set in the Minecraft universe. Instead of using the traditional Minecraft building and survival gameplay, the game focuses on exploring dungeons, fighting enemies, collecting equipment, and progressing through different levels. The game supports cooperative multiplayer, allowing players to work together while fighting enemies and completing objectives.

**Relation to my project:**
Minecraft Dungeons is one of the main gameplay inspirations for *Virelune*. I want my game to have a similar accessible dungeon-crawling structure with exploration, real-time combat, different enemies, and boss encounters. However, *Virelune* will be much smaller in scope and will not use Minecraft's world or assets. The major difference is that my game will be designed around two custom physical controllers. The two players will also have different character roles and abilities, making cooperation more important to the design.

---

## 2. Godot Engine

**Link:** https://godotengine.org/

**Kind of source:** Primary source. This is the official website for the Godot open-source game engine.

**Relation to my app:** Development framework that will be used to create *Virelune*.

**Description:**
Godot is a free and open-source game engine used for creating 2D and 3D games. It provides tools for game scenes, physics, animation, audio, scripting, user interfaces, input handling, and networking. Godot supports several programming languages, including its own GDScript language as well as C# and C++. The engine is designed to allow developers to build games without needing to create the entire underlying engine themselves.

**Relation to my project:**
Godot will be the primary software framework for *Virelune*. It will handle the game world, characters, enemies, combat, puzzles, menus, and other gameplay systems. I chose Godot because it is free, relatively lightweight, and provides the features needed for the project without requiring me to build a game engine from scratch. GDScript is also relatively approachable because its syntax is similar to Python, a language I have already worked with. Using Godot will allow me to spend more time developing the unique controller and cooperative gameplay systems.

---

## 3. Godot High-Level Multiplayer

**Link:** https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html

**Kind of source:** Primary technical source. This is official documentation maintained by the Godot project.

**Relation to my app:** Development resource for implementing two-player multiplayer.

**Description:**
Godot provides a high-level multiplayer API that allows developers to create networked games without having to implement every networking feature from the beginning. The system provides functionality for multiplayer peers, remote procedure calls, and synchronizing information between players. Godot supports different networking approaches depending on the requirements of the game.

**Relation to my project:**
*Virelune* is designed for two players who need to exist in the same game world. Multiplayer functionality may be used to synchronize information such as player movement, health, abilities, enemies, and puzzle states. Because the project is limited to two players, the networking system can remain relatively simple. This documentation will be useful when determining how player actions and game-state information should be communicated. The multiplayer implementation will also allow me to explore networking concepts without making the project dependent on a large online infrastructure.

---

## 4. Godot Input Documentation

**Link:** https://docs.godotengine.org/en/stable/tutorials/inputs/index.html

**Kind of source:** Primary technical source. This is official Godot documentation.

**Relation to my app:** Development resource for connecting the custom controllers to the game.

**Description:**
Godot provides an input system for detecting and responding to actions from keyboards, mice, gamepads, and other input sources. Developers can define actions and then use those actions within game scripts rather than directly tying gameplay code to individual physical buttons.

**Relation to my project:**
Input handling is especially important for *Virelune* because the game will not rely on a normal keyboard as its primary control method. The custom Arduino controllers will send information to the computer, and the game will need to interpret that information as gameplay actions. Godot's input system provides a useful framework for organizing those actions. For example, controller information could eventually be translated into actions such as attack, dodge, shield, spell, or interact. Separating the physical input from the actual game action should make the game easier to modify and test.

---

## 5. Arduino

**Link:** https://www.arduino.cc/

**Kind of source:** Primary source. This is the official Arduino website and documentation for Arduino hardware and software.

**Relation to my app:** Hardware platform for the two custom physical controllers.

**Description:**
Arduino is an open-source electronics platform consisting of microcontroller boards and development software. Arduino boards can read information from sensors, buttons, joysticks, and other electronic components and can use that information to control software or hardware. Arduino provides an accessible environment for developing embedded projects and physical computing devices.

**Relation to my project:**
Arduino will be used to build the custom controllers for *Virelune*. Each controller will contain physical inputs selected to match the character it represents. Possible components include joysticks, buttons, triggers, rotary controls, LEDs, and other components. The Arduino will read these inputs and send the resulting information to the computer running the game. Using Arduino also gives the project an embedded-systems component instead of making the project entirely software-based. The controller hardware is one of the major features that separates *Virelune* from a traditional dungeon-crawling game.

---

## 6. Arduino Serial Communication

**Link:** https://docs.arduino.cc/language-reference/en/functions/communication/serial/

**Kind of source:** Primary technical source. This is official Arduino documentation.

**Relation to my app:** Development resource for communication between the Arduino controllers and the computer.

**Description:**
Arduino provides serial communication functionality that allows a microcontroller to send and receive data. The Serial library includes functions for initializing communication and transmitting information over a serial connection. Serial communication is commonly used to connect an Arduino to a computer and exchange data between the two systems.

**Relation to my project:**
Serial communication will be the connection between the physical controllers and *Virelune*. Rather than making the controllers simply appear as generic gamepads, the project will use serial communication as part of its own controller protocol. The Arduino can send information such as joystick position, button states, and controller identification to the computer. The game can then read and interpret these messages. I also want to implement features such as joystick calibration and dead-zone handling. Designing this communication layer gives the project an additional software-engineering component and allows me to demonstrate how hardware and software can communicate through a protocol I designed.

---

## 7. Nintendo Labo

**Link:** https://www.nintendo.com/en-gb/games/oms/labo/index.html

**Kind of source:** Primary source. This is information published by Nintendo about Nintendo Labo.

**Relation to my app:** Similar product and inspiration for designing physical controllers around gameplay.

**Description:**
Nintendo Labo is a series of Nintendo Switch products that combine software with physical cardboard creations called Toy-Con. Players construct physical objects such as steering wheels, fishing rods, instruments, and other interfaces and then use them to interact with games. The physical objects are designed to provide a different way of interacting with the software.

**Relation to my project:**
Nintendo Labo is relevant because it demonstrates how the physical interface can become part of the game itself. *Virelune* follows a similar philosophy. Instead of designing a normal game and adding a controller afterward, I want the physical controllers and game mechanics to influence each other during development. The major difference is that my controllers will be custom-built around two different characters rather than being general-purpose Toy-Con devices. This supports the project's research question about whether asymmetric physical interfaces can encourage cooperation between players.

---

## 8. Makey Makey

**Link:** https://makeymakey.com/

**Kind of source:** Primary source. This is the official website for the Makey Makey invention kit.

**Relation to my app:** Similar product and reference for connecting physical objects to computer input.

**Description:**
Makey Makey is an invention kit that allows users to turn everyday conductive objects into computer inputs. The device can be connected to a computer and used to trigger keyboard or mouse-like inputs. This allows users to create unusual physical interfaces without having to design an entire electronic system themselves.

**Relation to my project:**
Makey Makey demonstrates the basic idea behind turning physical interaction into digital input. *Virelune* takes this concept further by building dedicated controllers rather than using everyday objects as inputs. The project will require the Arduino to directly read physical components and communicate their states to the game. Makey Makey is useful as an example of how changing the physical interface can change the way users interact with software. My project will explore this concept specifically through cooperative gameplay and character-specific controls.

---

## 9. HORI Arcade Controllers

**Link:** https://stores.horiusa.com/arcade-sticks/

**Kind of source:** Primary source. This is the official HORI USA website for its arcade controllers.

**Relation to my app:** Similar physical product and reference for specialized controller design.

**Description:**
HORI produces specialized gaming controllers, including arcade sticks designed around particular styles of gameplay. Arcade controllers generally use a joystick and multiple large physical buttons arranged in a layout intended for quick and deliberate inputs. Different models are designed for different games and player preferences.

**Relation to my project:**
HORI's controllers demonstrate that a specialized physical layout can provide a different experience from a standard gamepad. This is relevant to *Virelune* because each controller should have a purpose rather than simply copying a conventional controller. The Vanguard controller could emphasize quick combat and defensive actions, while the Arcanist controller could emphasize spell selection and ability activation. Looking at existing arcade controllers can help inform the physical arrangement and ergonomics of my own designs. However, unlike a commercial arcade stick, my controllers will be designed specifically for one game and its characters.

---

## 10. 8BitDo Arcade Stick

**Link:** https://www.8bitdo.com/arcade-stick/

**Kind of source:** Primary source. This is the official 8BitDo product website.

**Relation to my app:** Similar physical product and reference for customizable controller design.

**Description:**
The 8BitDo Arcade Stick is a gaming controller designed around the arcade-stick format. It provides a joystick and multiple buttons and is designed to allow users to customize the controller's behavior and configuration. It is intended for use with games where physical button and joystick inputs are important.

**Relation to my project:**
The 8BitDo Arcade Stick is useful as a reference for how physical controls can be arranged and customized for gaming. While *Virelune* will not need to provide the same level of general-purpose controller compatibility, the product demonstrates the value of designing the physical interface intentionally. My controllers can use this same general principle while going further by giving each player a different physical interface. The controller layout can reinforce the role of the character and make the player physically interact with the game in a way that a standard controller would not.

---

# Overall Relation to the Project

The sources in this bibliography support the major parts of *Virelune*. *Minecraft Dungeons* provides a gameplay reference for the project's cooperative dungeon-crawling structure, while Godot provides the game-development framework that will be used to build the actual game. Godot's networking and input documentation provide technical resources for implementing the two-player game and processing controller inputs.

Arduino and its serial communication documentation support the hardware portion of the project. They provide the foundation for building the custom controllers and communicating their inputs to the computer. Nintendo Labo, Makey Makey, HORI, and 8BitDo provide examples of how physical interfaces can be designed to change the way people interact with games.

The main difference between these existing products and *Virelune* is that the project combines **the custom hardware and the game into one design**. The controllers are not simply an alternative way to play an existing game. They will be designed specifically around the game's characters, abilities, and cooperative mechanics. The final goal is to demonstrate how custom physical interfaces can make two-player cooperation a more meaningful part of the gameplay experience.
