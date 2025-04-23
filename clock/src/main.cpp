#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define SERVICE_UUID "1a39d1af-53ab-447b-9368-6f36ba2a09b6"
#define CHARACTERISTIC_UUID_RX "1a39d1af-53ab-447b-9368-6f36ba2a09b7"
#define CHARACTERISTIC_UUID_TX "1a39d1af-53ab-447b-9368-6f36ba2a09b8"

BLEServer *server = NULL;
BLECharacteristic *pTxCharacteristic = NULL;
bool device_connected = false;
String currentTime = "00:00:00:0"; // Initial time

class Time {
  private:
  int hours;
  int minutes;
  int seconds;
  int day;

  public:
  void set(String value) {
    // Expected format: "HH:MM:SS:D"
    hours = value.substring(0, 2).toInt();
    minutes = value.substring(3, 5).toInt();
    seconds = value.substring(6, 8).toInt();
    day = value.substring(9).toInt();
    // updateString();
  }

  // void updateString() {
  //   currentTime = 
  //     String(hours).length() == 1 ? "0" + String(hours) : String(hours) + ":" +
  //     String(minutes).length() == 1 ? "0" + String(minutes) : String(minutes) + ":" +
  //     String(seconds).length() == 1 ? "0" + String(seconds) : String(seconds) + ":" +
  //     String(day);
  // }
  
  String toString() {
    return currentTime;
  }
} times;

class ServerCallbacks: public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    device_connected = true;
    Serial.println("Device connected");
  };
  
  void onDisconnect(BLEServer* pServer) {
    device_connected = false;
    Serial.println("Device disconnected");
    // Restart advertising
    BLEDevice::startAdvertising();
    server->startAdvertising();
  }
};

class Callbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pChar) {
    std::string rxValue = pChar->getValue();
    if (rxValue.length() > 0) {
      String received = String(rxValue.c_str());
      Serial.println("Received value: " + received);
      times.set(received);
      
      // Update TX characteristic
      pTxCharacteristic->setValue(times.toString().c_str());
      pTxCharacteristic->notify();
    }
  }
};

void setup() {
  Serial.begin(115200);
  BLEDevice::init("CLOCK825"); // Must match name Flutter is scanning for

  server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  BLEService *service = server->createService(SERVICE_UUID);

  // TX Characteristic (Notifications)
  pTxCharacteristic = service->createCharacteristic(
    CHARACTERISTIC_UUID_TX,
    BLECharacteristic::PROPERTY_NOTIFY | 
    BLECharacteristic::PROPERTY_READ
  );
  pTxCharacteristic->addDescriptor(new BLE2902());
  pTxCharacteristic->setValue(times.toString().c_str());

  // RX Characteristic (Write)
  BLECharacteristic *pRxCharacteristic = service->createCharacteristic(
    CHARACTERISTIC_UUID_RX,
    BLECharacteristic::PROPERTY_WRITE
  );
  pRxCharacteristic->setCallbacks(new Callbacks());

  service->start();
  
  // Advertising configuration
  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->setScanResponse(true);
  advertising->setMinInterval(0x20);    // 32 * 0.625ms = 20ms
  advertising->setMaxInterval(0x40);    // 64 * 0.625ms = 40ms
  advertising->setMinPreferred(0x20);   // 32 * 0.625ms = 20ms
  advertising->setMaxPreferred(0x40);   // 64 * 0.625ms = 40ms
  
  
  BLEDevice::startAdvertising();
  
  Serial.println("Waiting for connections...");
}

void loop() {
  if (device_connected) {
    // Send updates every second
    static unsigned long lastUpdate = 0;
    if (millis() - lastUpdate >= 1000) {
      pTxCharacteristic->setValue(times.toString().c_str());
      pTxCharacteristic->notify();
      lastUpdate = millis();
      Serial.println("Sent update: " + times.toString());
    }
  }
  delay(10);
}