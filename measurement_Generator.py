import json
import random
import math

def genereaza_date_birou(nume_fisier="telemetrie_birou.json", numar_linii=150):
    # 1. Variabila 'speed' se declară ÎNAINTE de buclă pentru a permite acumularea
    speed = 0.0
    
    with open(nume_fisier, 'a') as f:
        for i in range(numar_linii):
            # Nivelul de sateliți generat la fiecare pas
            satellites = random.randint(4, 8)
            
            if i < 20 or i > 120:
                # Relanti stabil
                rpm = int(random.gauss(820, 5)) 
                accel_pos = 0.0
                
                # Frână de motor: viteza scade treptat la relanti
                speed -= 0.5
                if speed < 0: 
                    speed = 0.0
            else:
                # Turare treptată până spre 4000 RPM
                faza = (i - 20) / 100.0 * math.pi
                rpm = int(820 + math.sin(faza) * 3200 + random.gauss(0, 30))
                
                # Poziția pedalei crește proporțional cu turația
                accel_pos = round((rpm - 820) / 3200.0 * 65.0 + random.gauss(0, 1.5), 1)
                if accel_pos < 0: 
                    accel_pos = 0.0

                accel_factor = (accel_pos / 100.0) * 1.8 
                drag_factor = 0.2 

                # Acumulare viteză de la pasul anterior
                speed += (accel_factor - drag_factor)
                if speed < 0: 
                    speed = 0.0

            # Conversie viteză întreagă pentru afișare OBD / JSON
            speed_km = int(speed)

            # 2. Sarcina motorului calculată logic în funcție de RPM
            engine_load = round(15.0 + (rpm - 820) / 3200.0 * 40.0 + random.gauss(0, 0.5), 1)

            # 3. Zgomotul senzorului ADXL345 stând pe birou (în jur de -0.62 G)
            g_force = round(random.gauss(-0.627626, 0.015), 6)

            # 4. Asamblarea structurii JSON
            data = {
                "timestamp": "LIVE",
                "nodes": {
                    "slave_simulator": {
                        "mcu": "Arduino Uno",
                        "data": {
                            "engine_rpm": rpm,
                            "vehicle_speed_km": speed_km,
                            "coolant_temp_c": 90,
                            "oil_temp_c": 92,
                            "engine_load_pct": engine_load,
                            "throttle_pos_pct": accel_pos
                        }
                    },
                    "master_telemetry": {
                        "mcu": "ESP32",
                        "data": {
                            "gps_speed_kmh": int(speed_km * 0.96), # Viteză GPS cu un mic offset față de senzorul OBD
                            "satellites_locked": satellites,
                            "g_force_x": g_force,
                            "latitude": "CENZURAT",
                            "longitude": "CENZURAT"
                        }
                    }
                }
            }
            
            # Scriere în fișier (o singură linie, format JSONL)
            f.write(json.dumps(data) + "\n")
            
    print(f"✅ Gata! Au fost generate {numar_linii} de pachete în fișierul '{nume_fisier}'.")

# Rularea funcției
if __name__ == "__main__":
    genereaza_date_birou(nume_fisier="measurement_real_simulator.json", numar_linii=200)