const int leftJoystickX = A0;
const int leftJoystickY = A1;

const int rightJoystickX = A2;
const int rightJoystickY = A3;

const int slider = A4;

const int encoderDT = 2;
const int encoderCLK = 4;

const int jumpButton = 6;
const int sprintButton = 7;

int lastCLKState;

unsigned long lastEncoderTime = 0;
const unsigned long encoderDebounce = 80;

int lastJumpButtonState = HIGH;
int lastSprintButtonState = HIGH;


void setup() {

  Serial.begin(9600);

  pinMode(encoderDT, INPUT_PULLUP);
  pinMode(encoderCLK, INPUT_PULLUP);

  pinMode(jumpButton, INPUT_PULLUP);
  pinMode(sprintButton, INPUT_PULLUP);

  lastCLKState = digitalRead(encoderCLK);
  lastJumpButtonState = digitalRead(jumpButton);
  lastSprintButtonState = digitalRead(sprintButton);
}


void loop() {

  // ==========================================
  // READ JOYSTICKS
  // ==========================================

  int leftX = analogRead(leftJoystickX);
  int leftY = analogRead(leftJoystickY);

  int rightX = analogRead(rightJoystickX);
  int rightY = analogRead(rightJoystickY);

  int sliderValue = analogRead(slider);


  // ==========================================
  // ROTARY ENCODER
  // ==========================================

  int currentCLKState = digitalRead(encoderCLK);

  if (currentCLKState != lastCLKState) {

    unsigned long currentTime = millis();

    if (currentTime - lastEncoderTime > encoderDebounce) {

      if (digitalRead(encoderDT) != currentCLKState) {

        Serial.println("ENCODER_RIGHT");

      } else {

        Serial.println("ENCODER_LEFT");
      }

      lastEncoderTime = currentTime;
    }

    lastCLKState = currentCLKState;
  }


  // ==========================================
  // JUMP BUTTON
  // ==========================================

  int currentJumpButtonState = digitalRead(jumpButton);

  if (currentJumpButtonState == LOW &&
      lastJumpButtonState == HIGH) {

    Serial.println("JUMP");
  }

  lastJumpButtonState = currentJumpButtonState;


  // ==========================================
  // SPRINT / L3 BUTTON
  // ==========================================

  int currentSprintButtonState = digitalRead(sprintButton);


  // L3 pressed

  if (currentSprintButtonState == LOW &&
      lastSprintButtonState == HIGH) {

    Serial.println("SPRINT");
  }


  // L3 released

  if (currentSprintButtonState == HIGH &&
      lastSprintButtonState == LOW) {

    Serial.println("SPRINT_RELEASE");
  }

  lastSprintButtonState = currentSprintButtonState;


  // ==========================================
  // SEND CONTROLLER VALUES
  // ==========================================

  Serial.print(leftX);
  Serial.print(",");

  Serial.print(leftY);
  Serial.print(",");

  Serial.print(rightX);
  Serial.print(",");

  Serial.print(rightY);
  Serial.print(",");

  Serial.println(sliderValue);


  delay(10);
}