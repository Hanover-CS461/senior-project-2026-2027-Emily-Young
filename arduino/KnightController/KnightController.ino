const int moveXPin = A0;
const int moveYPin = A1;

const int lookXPin = A2;
const int lookYPin = A3;

const int sprintPin = 2;
const int shieldPin = 3;
const int attackPin = 4;


void setup() {

  Serial.begin(9600);

  pinMode(sprintPin, INPUT_PULLUP);
  pinMode(shieldPin, INPUT_PULLUP);
  pinMode(attackPin, INPUT_PULLUP);
}


void loop() {

  int moveX = analogRead(moveXPin);
  int moveY = analogRead(moveYPin);

  int lookX = analogRead(lookXPin);
  int lookY = analogRead(lookYPin);

  bool sprint = digitalRead(sprintPin) == LOW;
  bool shield = digitalRead(shieldPin) == LOW;
  bool attack = digitalRead(attackPin) == LOW;


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