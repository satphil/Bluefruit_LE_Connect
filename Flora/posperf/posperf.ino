/*********************************************************************
 This is an example for our nRF51822 based Bluefruit LE modules

 Pick one up today in the adafruit shop!

 Adafruit invests time and resources providing this open source code,
 please support Adafruit and open-source hardware by purchasing
 products from Adafruit!

 MIT license, check LICENSE for more information
 All text above, and the splash screen below must be included in
 any redistribution
*********************************************************************/

/* ------------------------------------------------------------------

Extending above example, 
- set up Bluetooth connection
- gather 9dof (9 degrees of freedom) data and send over Bluetooth
- receive response from Bluetooth and buzz motor if required

Helen Diacono, 20 Oct 2015

------------------------------------------------------------------ */


#include <Wire.h>
#include <Arduino.h>
#include <SPI.h>
#include <Adafruit_NeoPixel.h>
#include <Adafruit_LSM9DS0.h>
#include <Adafruit_Sensor.h>
#if not defined (_VARIANT_ARDUINO_DUE_X_) && not defined (_VARIANT_ARDUINO_ZERO_)
  #include <SoftwareSerial.h>
#endif

#include <Adafruit_BLE.h>
#include <Adafruit_BluefruitLE_SPI.h>
#include <Adafruit_BluefruitLE_UART.h>

#include "BluefruitConfig.h"

// Create the bluefruit object, either software serial...uncomment these lines
/*
SoftwareSerial bluefruitSS = SoftwareSerial(BLUEFRUIT_SWUART_TXD_PIN, BLUEFRUIT_SWUART_RXD_PIN);

Adafruit_BluefruitLE_UART ble(bluefruitSS, BLUEFRUIT_UART_MODE_PIN,
                      BLUEFRUIT_UART_CTS_PIN, BLUEFRUIT_UART_RTS_PIN);
*/

/* ...or hardware serial, which does not need the RTS/CTS pins. Uncomment this line */
 Adafruit_BluefruitLE_UART ble(Serial1, BLUEFRUIT_UART_MODE_PIN);

/* ...hardware SPI, using SCK/MOSI/MISO hardware SPI pins and then user selected CS/IRQ/RST */
//Adafruit_BluefruitLE_SPI ble(BLUEFRUIT_SPI_CS, BLUEFRUIT_SPI_IRQ, BLUEFRUIT_SPI_RST);

/* ...software SPI, using SCK/MOSI/MISO user-defined SPI pins and then user selected CS/IRQ/RST */
//Adafruit_BluefruitLE_SPI ble(BLUEFRUIT_SPI_SCK, BLUEFRUIT_SPI_MISO,
//                             BLUEFRUIT_SPI_MOSI, BLUEFRUIT_SPI_CS,
//                             BLUEFRUIT_SPI_IRQ, BLUEFRUIT_SPI_RST);

Adafruit_NeoPixel strip = Adafruit_NeoPixel(1, 6, NEO_GRB + NEO_KHZ800);
// i2c 
// initialise 9dof sensor
Adafruit_LSM9DS0 lsm = Adafruit_LSM9DS0();

const int motorPin[3] = {10, 9, 6}; // array declaring which pins to use for vibe motors left, middle and right
int motor = 0; // index into motorPin
const int speed = 200; // to buzz vibe motor, drive pin at this speed (max = 255)
const int turnOff = 0; //turn off vibe motor
int a; // index into action for each motor


// A small helper
void error(const __FlashStringHelper*err) {
  Serial.println(err);
  while (1);
}

void setupSensor()
{
  // 1.) Set the accelerometer range
  lsm.setupAccel(lsm.LSM9DS0_ACCELRANGE_2G);
  //lsm.setupAccel(lsm.LSM9DS0_ACCELRANGE_4G);
  //lsm.setupAccel(lsm.LSM9DS0_ACCELRANGE_6G);
  //lsm.setupAccel(lsm.LSM9DS0_ACCELRANGE_8G);
  //lsm.setupAccel(lsm.LSM9DS0_ACCELRANGE_16G);
  
  // 2.) Set the magnetometer sensitivity
  lsm.setupMag(lsm.LSM9DS0_MAGGAIN_2GAUSS);
  //lsm.setupMag(lsm.LSM9DS0_MAGGAIN_4GAUSS);
  //lsm.setupMag(lsm.LSM9DS0_MAGGAIN_8GAUSS);
  //lsm.setupMag(lsm.LSM9DS0_MAGGAIN_12GAUSS);

  // 3.) Setup the gyroscope
  // This is the key sensor.  15 bits returned + sign (i.e. +/- 32,768)
  // indicates up to ~245 degrees per second rotation forward or back
  // so a value of 400 indicates ~3 degrees per second rotation
  // Spec indicates 0.00875 dps per unit so 400 = ~3.5dps. 
  lsm.setupGyro(lsm.LSM9DS0_GYROSCALE_245DPS);
  //lsm.setupGyro(lsm.LSM9DS0_GYROSCALE_500DPS);
  //lsm.setupGyro(lsm.LSM9DS0_GYROSCALE_2000DPS);
}

/**************************************************************************/
/*!
    @brief  Sets up the HW an the BLE module (this function is called
            automatically on startup)
*/
/**************************************************************************/
void setup(void)
{
  for (motor = 0; motor <= 2; motor++) 
    pinMode(motorPin[motor], OUTPUT); // declaring pins driving vibe motors are output pins

//  while (!Serial) {
//  
//  }  // required for Flora & Micro
  delay(500);

  Serial.begin(115200);
//  while (! Serial); // do nothing until serial is ready
  Serial.println(F("Posture Perfector"));
  Serial.println(F("-----------------"));

  strip.begin();
  strip.show();
  strip.setPixelColor(0, strip.Color(0, 0, 7)); // 
  strip.show();

  /* Initialise the module */
  Serial.print(F("Initialising the Bluefruit LE module: "));

  if ( !ble.begin(VERBOSE_MODE) )
  {
    error(F("Couldn't find Bluefruit, make sure it's in CoMmanD mode & check wiring?"));
  }
  Serial.println( F("OK!") );

  /* Perform a factory reset to make sure everything is in a known state */
  Serial.println(F("Performing a factory reset: "));
  if (! ble.factoryReset() ){
       error(F("Couldn't factory reset"));
  }

  /* Disable command echo from Bluefruit */
  ble.echo(false);

  Serial.println("Requesting Bluefruit info:");
  /* Print Bluefruit information */
  ble.info();

  Serial.println(F("Please use Adafruit Bluefruit LE app to connect in UART mode"));
  Serial.println(F("Then Enter characters to send to Bluefruit"));
  Serial.println();

  ble.verbose(false);  // debug info is a little annoying after this point!

  /* Wait for connection */
  while (! ble.isConnected()) {
      delay(500);
  }

  Serial.println(F("*****************"));
  
  Serial.println("LSMDS0 9dof raw read setup");
  
  // Try to initialise and warn if we couldn't detect the chip
  if (!lsm.begin())
  {
    Serial.println("Oops ... unable to initialize the LSM9DS0. Check your wiring!");
    while (1);
  }
  Serial.println("Found LSM9DS0 9DOF");
  Serial.println("");
  Serial.println("");
  
}

/**************************************************************************/
/*!
    @brief  Constantly poll for new command or response data
*/
/**************************************************************************/
void loop(void)
{
 //TX Talk via Bluetooth to iPhone

  ble.print("AT+BLEUARTTX=");
  lsm.read();
  
  ble.print("!"); // start data transmission
  ble.print("A"); // data type
  ble.print("0"); //sensor ID
  ble.print(lsm.accelData.x); 
  ble.print("@");
  ble.print(lsm.accelData.y); 
  ble.print("@");
  ble.print(lsm.accelData.z); 
  
// Although gyroData.x is defined as a float, 
// it is actually a 16 bit signed integer
// where a value of 1 = 0.00875 degrees per second
  
  ble.print("!"); // start data transmission
  ble.print("G"); // data type
  ble.print("0"); //sensor ID
  ble.print(lsm.gyroData.x); 
  ble.print("@");
  ble.print(lsm.gyroData.y); 
  ble.print("@");
  ble.print(lsm.gyroData.z); 
  
  ble.print("!"); // start data transmission
  ble.print("M"); // data type
  ble.print("0"); //sensor ID
  ble.print(lsm.magData.x); 
  ble.print("@");
  ble.print(lsm.magData.y); 
  ble.print("@");
  ble.print(lsm.magData.z); 
  
  ble.println();
  
  if (! ble.waitForOK() ) {
     Serial.println(F("Failed to send to iPhone via Bluetooth?"));
  }
  
 // Check for commands from iPhone received via Bluetooth
 ble.println("AT+BLEUARTRX");
 ble.readline();
 if (strcmp(ble.buffer, "OK") == 0) {
   // no data
   Serial.println(F("received no data from Bluetooth"));
   return;
 }
 // Some data was found, it's in the buffer
 // Expecting command of format "!Bn@" for n in 0..3
 // 0 implying no buzzers; 1..3 implying buzzer 1..3
 Serial.print(F("[Recv] ")); Serial.println(ble.buffer);
 
 if (strcmp(ble.buffer, "!B0@") == 0) {
     // buzz left vibe motor
     motor = 0; // arrays indexed from zero so left motor is motor zero
     strip.setPixelColor(0, strip.Color(7, 0, 7)); // red+blue= magenta light
  } else 
    if (strcmp(ble.buffer, "!B1@") == 0) {
       // buzz middle vibe motor
       motor = 1;
       strip.setPixelColor(0, strip.Color(7, 7, 0)); // red+green= yellow light
     } else 
       if (strcmp(ble.buffer, "!B2@") == 0) {
         // buzz right vibe motor
         motor = 2;
         strip.setPixelColor(0, strip.Color(0, 7, 7)); // green+blue= cyan light
       } else 
         if (strcmp(ble.buffer, "!B3@") == 0) {
           // posture is OK
           motor = 3;      // no vibe motor is buzzed
           strip.setPixelColor(0, strip.Color(0, 7, 0)); // green light
          } else  { 
              Serial.println(F("Unexpected response from iPhone"));
              motor = 4;   // no vibe motor to be buzzed
              strip.setPixelColor(0, strip.Color(7, 0, 0)); // red light!
            }
 strip.show();

 for (a = 0; a <= 2 ; a++) { //cycle through actions for each motor
   if ( a == motor ) {   // is this motor to be turned on?
     analogWrite(motorPin[a], speed); // turn on motor
     delay (500);                     // buzz for half a second (if on) 
   }
   analogWrite(motorPin[a], turnOff);   // then turn off (all) motors
 }
  
 if (! ble.waitForOK() ) {
   Serial.println(F("Failed to receive from iPhone via Bluetooth?"));
 }

 delay(750);  // 0.75s seems minimum delay between 9dof readings and bluetooth sendings

}

