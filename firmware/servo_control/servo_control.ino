#include <ESP32Servo.h>

#define ROTATE_SERVO_PIN 18
#define TRIGGER_SERVO_PIN 19
#define RX_PIN 7

Servo rotate_servo;
Servo trigger_servo;

const long pcBaudRate = 115200;
const long deviceBaudRate = 115200;

void setup() {
  // Allow allocation of all timers
  ESP32PWM::allocateTimer(0);
  ESP32PWM::allocateTimer(1);
  ESP32PWM::allocateTimer(2);
  ESP32PWM::allocateTimer(3);
  
  // LD-25MG works best with a 50Hz frequency
  rotate_servo.setPeriodHertz(50);
  trigger_servo.setPeriodHertz(50);   

  // Attach with the LD-25MG specific pulse widths: 500us to 2500us
  rotate_servo.attach(ROTATE_SERVO_PIN, 500, 2500);
  trigger_servo.attach(TRIGGER_SERVO_PIN, 500, 2500);
  Serial.begin(pcBaudRate);
  rotate_servo.write(90);
  trigger_servo.write(135);
  
  while (!Serial) {
    ;
  }

  // Initialize communication with the FPGA (UART1)
  Serial1.begin(deviceBaudRate, SERIAL_8E1, RX_PIN);
  Serial.print("Listening on GPIO ");
  Serial.println(RX_PIN);
}

void loop() {
  if (Serial1.available()) {
    int8_t angle = Serial1.read();
    
    // Forward the byte to the Serial Monitor
    Serial.print(angle);
    Serial.print("\n");

    // Validate range
    if (angle >= -90 && angle <= 90) {
      Serial.printf("Moving to %d degrees\n", angle);
      rotate_servo.write(90 - angle);
      delay(1000);
      trigger_servo.write(125);
      Serial.println("Pulled trigger.");
      delay(1000);
      trigger_servo.write(135);
      Serial.println("Reset trigger.");
    } else {
      Serial.println("Invalid angle!");
    }
  }
}