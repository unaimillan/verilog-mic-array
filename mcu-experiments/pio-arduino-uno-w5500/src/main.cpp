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
  // Serial.begin(9600);
  // Serial.begin(115200);
  Serial.begin(1000000);
  while (!Serial) { ; }   // wait for serial monitor (optional)

  Serial.println("Serial booted.");
  delay(1000);

  // Set the correct CS pin for W5500
  Ethernet.init(PIN_SPI_SS);

  // Start Ethernet with static IP (no DHCP)
  Ethernet.begin(mac, localIP, gateway, subnet);

  // Wait for the Ethernet to initialise
  delay(1000);

  // Initialise UDP – we bind to a local port (send‑only, no listen)
  Udp.begin(localPort);

  delay(1000);

  IPAddress              cur_localip    = Ethernet.localIP();
  IPAddress              cur_remoteip   = Udp.remoteIP();
  uint16_t               cur_remoteport = Udp.remotePort();
  EthernetLinkStatus     cur_link       = Ethernet.linkStatus();
  EthernetHardwareStatus cur_hw         = Ethernet.hardwareStatus();
  int                    cur_udp        = Udp.available();

  delay(1000);

  // Print local IP for debugging
  Serial.print("Local IP: ");
  Serial.println( cur_localip );
  Serial.print("Sending to: ");
  // Serial.print(targetIP);
  Serial.print( cur_remoteip );
  Serial.print(":");
  Serial.println( cur_remoteport );

  Serial.print("Link status: ");
  Serial.println((int32_t)  cur_link );
  Serial.print("Hardware status: ");
  Serial.println((int32_t)  cur_hw );
  Serial.print("Udp available: ");
  Serial.println( cur_udp );

  // Check for Ethernet hardware present
  if (cur_hw == EthernetNoHardware) {
    Serial.println("Ethernet shield was not found. Sorry, can't run without hardware. :(");
    while (true) {
      delay(1); // do nothing, no point running without Ethernet hardware
    }
  }
  if (cur_link == LinkOFF) {
    Serial.println("Ethernet cable is not connected.");
  }

  Serial.println("Ready to start?");
  delay(3000);
}

uint8_t prbs_state = 2;

static inline uint8_t prbs7_next(uint8_t state) {
    // feedback = XOR of bit6 and bit5 (0-indexed)
    // (state>>6) and (state>>5) are each 0 or 1, so XOR is already 0/1 – no &1 needed
    return ((state << 1) | ((state >> 6) ^ (state >> 5))) & 0x7F;
}

// ========== Main Loop ==========
void loop() {
  // Read the four analog pins (10‑bit values 0–1023)
  const uint32_t DATA_N = 16;
  int16_t readings[DATA_N];
  
  for (uint8_t i = 0; i < DATA_N; i ++) {
    readings[i] = (int16_t) prbs_state;
    // prbs_state = prbs7_next(prbs_state);
    prbs_state += 1;
  }
  
  // readings[0] = (int16_t) analogRead(A0);
  // readings[1] = (int16_t) analogRead(A1);
  // readings[2] = (int16_t) analogRead(A2);
  // readings[3] = (int16_t) analogRead(A3);

  // Pack the 4 int16_t values into a byte buffer (8 bytes total)
  uint8_t packetBuffer[DATA_N * 2];
  memcpy(packetBuffer, readings, sizeof(readings));

  // Send the packet via UDP (no receive, just send)
  Udp.beginPacket(targetIP, targetPort);
  Udp.write(packetBuffer, DATA_N*2);
  Udp.endPacket();

  if (true)
  {
    // if (random(1, 4) == 1)
    {
      // delay(500);
      // Optional debug output to Serial
      Serial.print("Sent: ");
      for (u32 i = 0; i < DATA_N; i++) {
        Serial.print(readings[i]);
        Serial.print(" ");
      }
      Serial.println();
    }

    // Wait before next send (adjust as needed)
    delay(100);
  }
}


	// Serial.print(">w a ");
	// Serial.print(addr, HEX);
	// Serial.print(", d[");
	// Serial.print(len);
	// Serial.print("] ");
	// for (u32 i = 0; i < len; i ++){
	// 	Serial.print(buf[i], HEX);
	// }
	// Serial.println();
	// delay(100);

	// Serial.print(">r a ");
	// Serial.print(addr, HEX);
	// Serial.print(", d[");
	// Serial.print(len);
	// Serial.print("] ");
	// for (u32 i = 0; i < len; i ++){
	// 	Serial.print(buf[i], HEX);
	// }
	// Serial.println();
	// delay(100);

	
	// if (addr != 0x1002){
	// 	Serial.print(">SPI read: addr ");
	// 	Serial.print(addr, HEX);
	// 	Serial.print(", data[");
	// 	Serial.print(len);
	// 	Serial.print("] ");
	// 	for (u32 i = 0; i < len; i ++){
	// 		Serial.print(buf[i], HEX);
	// 	}
	// 	Serial.println();
	// 	delay(100);
	// }


	// Serial.print(">SPI write: addr ");
	// Serial.print(addr, HEX);
	// Serial.print(", data[");
	// Serial.print(len);
	// Serial.print("] ");
	// for (u32 i = 0; i < len; i ++){
	// 	Serial.print(buf[i], HEX);
	// }
	// Serial.println();
	// delay(100);