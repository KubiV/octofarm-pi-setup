// Pro komunikaci z počítače můžete posílat příkazy jako:
// "R1:1" - zapne relé 1
// "R1:0" - vypne relé 1
// "R2:1" - zapne relé 2

// Definice pinů pro relé
const int relayPins[] = {2, 3, 4, 5}; // Piny pro relé
const int numRelays = 4;               // Počet relé

void setup() {
  // Nastavení všech pinů relé jako výstup
  for (int i = 0; i < numRelays; i++) {
    pinMode(relayPins[i], OUTPUT);
    digitalWrite(relayPins[i], HIGH); // Výchozí stav relé je vypnutý
  }

  // Spuštění sériové komunikace
  Serial.begin(9600);
  Serial.println("Systém relé připraven. Formát příkazu: R<číslo_relé>:<stav> (např. R1:1)");
  Serial.println("Dostupná relé: 1 až " + String(numRelays));
}

void loop() {
  // Kontrola příchozích dat na sériovém portu
  if (Serial.available() > 0) {
    String command = Serial.readStringUntil('\n'); // Čtení příkazu až do nového řádku
    command.trim(); // Odstranění mezer a nových řádků

    // Kontrola formátu příkazu (např. R1:1)
    if (command.startsWith("R") && command.indexOf(":") != -1) {
      // Rozdělení příkazu na číslo relé a stav
      int colonIndex = command.indexOf(":");
      String relayStr = command.substring(1, colonIndex);     // Číslo relé (např. "1")
      String stateStr = command.substring(colonIndex + 1);    // Stav (např. "1" nebo "0")

      // Konverze čísla relé na integer
      int relayNum = relayStr.toInt();

      // Kontrola platnosti čísla relé
      if (relayNum >= 1 && relayNum <= numRelays) {
        int relayIndex = relayNum - 1; // Index pole (0-based)

        // Zpracování stavu
        if (stateStr == "1") {
          digitalWrite(relayPins[relayIndex], LOW);
          Serial.println("Relé " + String(relayNum) + ": ZAPNUTO");
        } else if (stateStr == "0") {
          digitalWrite(relayPins[relayIndex], HIGH);
          Serial.println("Relé " + String(relayNum) + ": VYPNUTO");
        } else {
          Serial.println("Neplatný stav. Použijte 1 (zapnout) nebo 0 (vypnout)");
        }
      } else {
        Serial.println("Neplatné číslo relé. Použijte 1 až " + String(numRelays));
      }
    } else {
      Serial.println("Neplatný formát příkazu. Použijte R<číslo_relé>:<stav> (např. R1:1)");
    }
  }
}
