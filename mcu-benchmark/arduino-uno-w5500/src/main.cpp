#include <Arduino.h>
#include <Ethernet.h>
#include <EthernetUdp.h>


// ========== Configuration (all constants) ==========

// MAC address (must be unique on your network)
byte mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };

// Local static IP, gateway, subnet mask
IPAddress localIP(192, 168, 1, 10);
IPAddress gateway(192, 168, 1, 1);
IPAddress subnet(255, 255, 255, 0);
const unsigned int localPort = 8880;

// Target (receiver) IP and port
IPAddress targetIP(192, 168, 1, 100);
const unsigned int targetPort = 8888;

// W5500 CS pin (usually pin 10)
const int w5500_CS = 10;

// Create UDP object
EthernetUDP Udp;

// ========== Setup ==========

void setup() {
  Serial.begin(9600);
//   Serial.begin(115200);
  while (!Serial) { ; }   // wait for serial monitor (optional)

  // Set the correct CS pin for W5500
  Ethernet.init(w5500_CS);

  // Start Ethernet with static IP (no DHCP)
  Ethernet.begin(mac, localIP, gateway, subnet);

  // Wait for the Ethernet to initialise
  delay(1000);

  // Initialise UDP – we bind to a local port (send‑only, no listen)
  Udp.begin(localPort);

  delay(1000);

  // Print local IP for debugging
  Serial.print("Local IP: ");
  Serial.println(Ethernet.localIP());
  Serial.println("Sending to: ");
  Serial.print(targetIP);
  Serial.print(":");
  Serial.println(targetPort);

  // Check for Ethernet hardware present
  if (Ethernet.hardwareStatus() == EthernetNoHardware) {
    Serial.println("Ethernet shield was not found. Sorry, can't run without hardware. :(");
    while (true) {
      delay(1); // do nothing, no point running without Ethernet hardware
    }
  }
  if (Ethernet.linkStatus() == LinkOFF) {
    Serial.println("Ethernet cable is not connected.");
  }

  Serial.println("Link status: ");
  Serial.println((uint32_t) Ethernet.linkStatus);
  Serial.print(", hardware status: ");
  Serial.println((uint32_t) Ethernet.hardwareStatus);
}

// ========== Main Loop ==========
void loop() {
  // Read the four analog pins (10‑bit values 0–1023)
  int16_t readings[4];
  readings[0] = (int16_t) analogRead(A0);
  readings[1] = (int16_t) analogRead(A1);
  readings[2] = (int16_t) analogRead(A2);
  readings[3] = (int16_t) analogRead(A3);

  // Pack the 4 int16_t values into a byte buffer (8 bytes total)
  uint8_t packetBuffer[8];
  memcpy(packetBuffer, readings, sizeof(readings));

  // Send the packet via UDP (no receive, just send)
  Udp.beginPacket(targetIP, targetPort);
  Udp.write(packetBuffer, 8);
  Udp.endPacket();

  // if (random(1, 4) == 1)
  {
    // Optional debug output to Serial
    Serial.print("Sent: ");
    for (int i = 0; i < 4; i++) {
      Serial.print(readings[i]);
      Serial.print(" ");
    }
    Serial.println();
  }

  // Wait before next send (adjust as needed)
  delay(100);
}
