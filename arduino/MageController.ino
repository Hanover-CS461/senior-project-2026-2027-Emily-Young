const int leftJoystickX = A0;
const int leftJoystickY = A1;

const int rightJoystickX = A2;
const int rightJoystickY = A3;

const int slider = A4;


void setup() {
  Serial.begin(9600);
}


void loop() {

  int leftX = analogRead(leftJoystickX);
  int leftY = analogRead(leftJoystickY);

  int rightX = analogRead(rightJoystickX);
  int rightY = analogRead(rightJoystickY);

  int sliderValue = analogRead(slider);


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