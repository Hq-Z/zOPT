#include <SPI.h>
#include <AMIS30543.h>
#include <AccelStepper.h>
// -------------------------------------------------------------------------
//  Please refer to our paper for more details:
// 
//  "zOPT: an open source Optical Projection Tomography system and methods for
//  rapid 3D zebrafish imaging"
//  HANQING ZHANG,LAURA WALDMANN,REMY MANUEL,TATJANA HAITINA,AND AMIN ALLALOU
//  
//  Authors information:
//    hanqing.zhang@it.uu.se
//    amin.allalou@it.uu.se
// 
//  Copyright 2020,  1. BioImage Informatics Facility at SciLifeLab,Sweden
//                   2. Division of Visual information and interaction, 
//                      Department of Information Technology, Uppsala university,Sweden
// 
//  License: The program is distributed under the terms of the GNU General 
//  Public License v3.0
//  Contact: Version 1.0 - first release, 20200207, zhanghq0088@gmail.com
//  Website: https://github.com/Hq-Z/zOPT
// -------------------------------------------------------------------------

// Assign default pins AMIS30543
const uint8_t amisDirPin = 2;
const uint8_t amisStepPin = 3;
const uint8_t amisSlaveSelect = 4;

const int InitialTimeStep =700;
const int AcceleratingTimeStep= 1;
const int FinalTimeStep= 250; // !This is for fast rotation. Change this depending on the quality of your motor. smaller number faster rotation.

// Assign registers names for AMIS30543
enum regAddr
{
  WR  = 0x0,
  CR0 = 0x1,
  CR1 = 0x2,
  CR2 = 0x3,
  CR3 = 0x9,
  SR0 = 0x4,
  SR1 = 0x5,
  SR2 = 0x6,
  SR3 = 0x7,
  SR4 = 0xA,
};

// Set initial user parameters
int pulseWidth=2; // Pulse width for stepping, microseconds

int numSteps = 1000; // Number of micro-steps per 'step'
long numStepsFloat = 1000; // Number of micro-steps per 'step'
int speedDelay = 200; // Time delay of each step signal in microseconds

int currentLimit=128; // Maximum driving current for motor in miliamp.
int microsteps=32; // number of micro-steps in a full step.

int serialCommDelay=25; // Time delay

int substeps= 32; 
int substeps_tmp= 0; 

// Set Driver AMIS30543
AMIS30543 stepper;

void setup()
{
  // Turn off the yellow LED.
  pinMode(LED_BUILTIN, OUTPUT);

  // Serial and SPI communication
  digitalWrite(SS, HIGH);  // ensure SS stays high
  SPI.begin();
  stepper.init(amisSlaveSelect);
  SPI.attachInterrupt();

    // Ready
  digitalWrite(LED_BUILTIN, HIGH); // Turn on the yellow LED.
  delay(1000);
  digitalWrite(LED_BUILTIN, LOW); // Turn on the yellow LED.
  delay(1000);

  Serial.begin(9600);

  // Drive the NXT/STEP and DIR pins low initially.
  digitalWrite(amisStepPin, LOW);
  pinMode(amisStepPin, OUTPUT);
  digitalWrite(amisDirPin, LOW);
  pinMode(amisDirPin, OUTPUT);

  // Give the driver some time to power up.
  delay(1);

  // Reset the driver to its default settings.
  stepper.resetSettings();
  delay(1);
  
  // Set the current limit. 
  stepper.setCurrentMilliamps(currentLimit);
  // Set the number of microsteps that correspond to one full step.
  stepper.setStepMode(microsteps);

  // Enable the motor outputs.
  stepper.enableDriver();
  setDirection(0);
  
  // Serial monitor menu
  Serial.println(F(" m = mode")); 
  Serial.println(F(" r = dir anti clockwise "));
  Serial.println(F(" l = dir clockwise"));
  Serial.println(F(" e = driver on "));
  Serial.println(F(" o = driver in stand by"));
  Serial.println(F(" s = step"));
  Serial.println(F(" v = vstep"));
  Serial.println(F(" f = frequency or speed"));
  Serial.println(F(" p = sleep mode"));
  Serial.println(F(" w = stop sleep mode"));
  Serial.println(F(" i = show current status"));

  // Ready
  digitalWrite(LED_BUILTIN, HIGH); // Turn on the yellow LED.
  delay(1000);
}

void loop()
{
  //check serial port for 
  if (Serial.available()) {
    int charnr=0;
    char command;
    String readString;
    // Check command type
    while (Serial.available()) {
      delay(5);  // Time for acquiring data
      if (Serial.available() >0) { 
        char c = Serial.read();
        if (charnr==0)
          command=c;
        else
          readString += c;
        charnr++;
        }
      }
    Serial.println(readString);
    // Operations based on each command
    switch (command) { 
    case 'e': 
         stepper.enableDriver();
         if (stepper.driver.readReg(CR2) != 0x80)
          {
            Serial.println(F("Error: EnableDriver failed."));
            error();
          }
          else
          {
            Serial.println("Driver on ");
            delay(serialCommDelay);
          }
          break;
    case 'o':
          stepper.disableDriver(); 
          if (stepper.driver.readReg(CR2) != 0x00)
          {
            Serial.println(F("Error: DisableDriver failed."));
            error();
          }
          else
          {
            Serial.println("Driver off");
            delay(serialCommDelay);
          }
          break;
    case 'p': 
          stepper.enableDriver();
          stepper.sleep();
          Serial.println("Driver is on sleep mode");
          delay(serialCommDelay);
          break;
    case 'w': 
          stepper.enableDriver();
          stepper.sleepStop();
          Serial.println("Driver has stopped sleep mode");
          delay(serialCommDelay);
          break;
  // motor direction
    case 'l': 
          stepper.setDirection(0);
          Serial.println("Direction clock wise");
          delay(serialCommDelay);
          break;
  // define the ccw motor direction 
    case 'r': 
          stepper.setDirection(1);
          Serial.println("Direction counter clock wise");
          delay(serialCommDelay);
          break;
    case 's':
           //numSteps=readString.toInt();
           numStepsFloat=atol(readString.c_str());
           Serial.println(F("Step number is set to "));
           Serial.println(numSteps, DEC);
           Serial.println(F(" steps."));
           stepFloat(numStepsFloat,speedDelay);
           //step(numSteps,speedDelay);
           Serial.println(F("Completed"));
           break;
    case 'v': 
           numSteps=readString.toInt();
           Serial.println(F("Fast mode on : "));
           Serial.println(numSteps, DEC);
           Serial.println(F(" steps."));
           Faststep(numSteps);
           Serial.println(F("Fast mode off"));
           break;
    case 'f': // speed number
            speedDelay=readString.toInt();
            Serial.println(F("Delay time between steps is "));
            Serial.println(speedDelay, DEC);
            Serial.println(F("microscronds."));
            //step(numSteps,speedDelay);
            break;
    case 't': // speed number
       
            if (readString[0] == 'l')
            {
              stepper.setDirection(0); 
              Serial.println(F("Dir 0 "));
            }
            else
            {
              stepper.setDirection(1);
              Serial.println(F("Dir 1 "));
            }
              
           numSteps=readString.substring(1).toInt();
           //Serial.println(F("Step number is set to "));
           //Serial.println(numSteps, DEC);
           //Serial.println(F(" steps."));
           step(numSteps,speedDelay);
           //Serial.println(F("Completed"));
           break;
    case 'm': 
           substeps_tmp=readString.toInt();
           if(substeps_tmp>0)
           {  if(substeps_tmp<2)
              {
                substeps=1;
              }
              else if(substeps_tmp<4)
              {
                substeps=2;
              }
              else if(substeps_tmp<8)
              {
                substeps=4;
              }
              else if(substeps_tmp<16)
              {
                substeps=8;
              }
              else if(substeps_tmp<32)
              {
                substeps=16;
              }
              else if(substeps_tmp<64)
              {
                substeps=32;
              }
              else if(substeps_tmp<128)
              {
                substeps=64;
              }
              else if(substeps_tmp<256)
              {
                substeps=128;
              }
              else
              {
                substeps=32;
              }
            }
            else
            { 
              substeps=32;
            }
           Serial.println(F("The number of sub steps are "));
           Serial.println(substeps, DEC);
           stepper.setStepMode(substeps);
           //step(numSteps,speedDelay);
           break;
     case 'i': 
         uint8_t cr2 = readReg(CR2);
         if (cr2 == 0xC0)
         {
          Serial.println(F("SleepMode: On "));
          Serial.println(F("Driver: Enabled "));
         }
         else if (cr2 == 0x80)
         {
           Serial.println(F("SleepMode: Off "));
           Serial.println(F("Driver: Enabled "));
         }
         else if (cr2 == 0x00)
         {
          Serial.println(F("SleepMode: unknown "));
          Serial.println(F("Driver: Disabled "));
         }
         else
         {
           Serial.println(F("SleepMode: unknown "));
           Serial.println(F("Driver: unknown "));
          }

         Serial.println(F("Current limit is set to "));
         Serial.println(currentLimit, DEC);
         
         Serial.println(F("Step number is set to "));
         Serial.println(numSteps, DEC);
           
         Serial.println(F("Delay time between steps is "));
         Serial.println(speedDelay, DEC);

         Serial.println(F("The number of sub steps are "));
         Serial.println(substeps, DEC);
    }
    }
}

// Sends a pulse on the NXT/STEP pin to tell the driver to take
// one step, and also delays to control the speed of the motor.
void step(int numSteps,int speedDelay)
{
  // The NXT/STEP minimum high pulse width is X microseconds.
  for ( int i = 0; i < numSteps; i++) {
    digitalWrite(amisStepPin, HIGH);
    delayMicroseconds(pulseWidth);
    digitalWrite(amisStepPin, LOW);
    delayMicroseconds(pulseWidth);
    // The delay here controls the stepper motor's speed.  You can
    // increase the delay to make the stepper motor go slower.  If
    // you decrease the delay, the stepper motor will go fast, but
    // there is a limit to how fast it can go before it starts
    // missing steps.
    delayMicroseconds(speedDelay);
  }
}
void stepFloat(long numSteps,int speedDelay)
{
  // The NXT/STEP minimum high pulse width is X microseconds.
  for ( long i = 0; i < numSteps; i++) {
    digitalWrite(amisStepPin, HIGH);
    delayMicroseconds(pulseWidth);
    digitalWrite(amisStepPin, LOW);
    delayMicroseconds(pulseWidth);
    // The delay here controls the stepper motor's speed.  You can
    // increase the delay to make the stepper motor go slower.  If
    // you decrease the delay, the stepper motor will go fast, but
    // there is a limit to how fast it can go before it starts
    // missing steps.
    delayMicroseconds(speedDelay);
  }
}

void Faststep(int numSteps){  // Acceleration part
 digitalWrite(amisStepPin, HIGH);
 for (int i = InitialTimeStep; i > FinalTimeStep; i = i-AcceleratingTimeStep){
   for (int x = 0; x < 200; x++) {
    digitalWrite(amisStepPin, HIGH);
    delayMicroseconds(i);
    digitalWrite(amisStepPin, LOW);
    delayMicroseconds(i);
   }
}

 for (int i = InitialTimeStep; i < numSteps; i = i++) {
     for (int x = 0; x < 200; x++) {
     digitalWrite(amisStepPin, HIGH);
     delayMicroseconds(FinalTimeStep);
     digitalWrite(amisStepPin, LOW);
     delayMicroseconds(FinalTimeStep);
    }
 }

}
// Writes a high or low value to the direction pin to specify
// what direction to turn the motor.
void setDirection(bool dir)
{
  // The NXT/STEP pin must not change for at least 0.5
  // microseconds before and after changing the DIR pin.
  delayMicroseconds(1);
  digitalWrite(amisDirPin, dir);
  delayMicroseconds(1);
}

uint8_t readReg(uint8_t address)
{
  return stepper.driver.readReg(address);
}

void error()
{
  stepper.disableDriver();
  while(1)
  {
  }
}
