const int moveXPin = A0;
const int moveYPin = A1;

const int lookXPin = A2;
const int lookYPin = A3;

const int sprintPin = 2;
const int shieldPin = 3;
const int attackPin = 4;
const int jumpPin = 5;
const int interactPin = 6;
const int dodgePin = 7;

int lastJumpState = HIGH;
int lastInteractState = HIGH;
int lastDodgeState = HIGH;


void setup() {

  Serial.begin(9600);

  pinMode(sprintPin, INPUT_PULLUP);
  pinMode(shieldPin, INPUT_PULLUP);
  pinMode(attackPin, INPUT_PULLUP);
  pinMode(jumpPin, INPUT_PULLUP);
  pinMode(interactPin, INPUT_PULLUP);
  pinMode(dodgePin, INPUT_PULLUP);

  lastJumpState = digitalRead(jumpPin);
  lastInteractState = digitalRead(interactPin);
  lastDodgeState = digitalRead(dodgePin);
}


void loop() {

  // ==========================================
  // READ JOYSTICKS
  // ==========================================

  int moveX = analogRead(moveXPin);
  int moveY = analogRead(moveYPin);

  int lookX = analogRead(lookXPin);
  int lookY = analogRead(lookYPin);


  // ==========================================
  // READ BUTTONS
  // ==========================================

  bool sprint = digitalRead(sprintPin) == LOW;
  bool shield = digitalRead(shieldPin) == LOW;
  bool attack = digitalRead(attackPin) == LOW;


  // ==========================================
  // JUMP BUTTON
  // ==========================================

  int currentJumpState = digitalRead(jumpPin);

  if (
    currentJumpState == LOW &&
    lastJumpState == HIGH
  ) {

    Serial.println("JUMP");
  }

  lastJumpState = currentJumpState;


  // ==========================================
  // INTERACTION BUTTON
  // ==========================================

  int currentInteractState = digitalRead(interactPin);

  if (
    currentInteractState == LOW &&
    lastInteractState == HIGH
  ) {

    Serial.println("INTERACT");
  }

  lastInteractState = currentInteractState;


  // ==========================================
  // DODGE BUTTON
  // ==========================================

  int currentDodgeState = digitalRead(dodgePin);

  if (
    currentDodgeState == LOW &&
    lastDodgeState == HIGH
  ) {

    Serial.println("DODGE");
  }

  lastDodgeState = currentDodgeState;


  // ==========================================
  // SEND CONTROLLER VALUES
  // ==========================================

  Serial.print("MOVE:");
  Serial.print(moveX);
  Serial.print(",");
  Serial.print(moveY);

  Serial.print("|LOOK:");
  Serial.print(lookX);
  Serial.print(",");
  Serial.print(lookY);

  Serial.print("|SPRINT:");
  Serial.print(sprint ? 1 : 0);

  Serial.print("|SHIELD:");
  Serial.print(shield ? 1 : 0);

  Serial.print("|ATTACK:");
  Serial.println(attack ? 1 : 0);


  delay(20);
}