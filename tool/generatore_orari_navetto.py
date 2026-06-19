import json
from datetime import datetime, timedelta

def genera_intervallo(inizio, fine, frequenza_minuti):
    """Genera una lista di orari HH:MM in un intervallo dato."""
    orari = []
    curr = datetime.strptime(inizio, "%H:%M")
    limite = datetime.strptime(fine, "%H:%M")
    
    while curr <= limite:
        orari.append(curr.strftime("%H:%M"))
        curr += timedelta(minutes=frequenza_minuti)
    return orari

def inserisci_corse(calendario, data_str, linea, orari_da_inserire):
    """Inserisce gli orari nel dizionario, mantenendo l'ordine cronologico senza duplicati."""
    if data_str not in calendario:
        calendario[data_str] = {}
    if linea not in calendario[data_str]:
        calendario[data_str][linea] = []
        
    insieme_orari = set(calendario[data_str][linea] + orari_da_inserire)
    calendario[data_str][linea] = sorted(list(insieme_orari))

# Inizializzazione calendario completo
navetto_calendario = {}

# 1. GENERAZIONE GIORNATE STANDARD (Date singole e intervalli dal PDF)
TUTTE_LE_DATE = []
start_date = datetime(2026, 4, 25)
end_date = datetime(2026, 9, 13)
curr = start_date
while curr <= end_date:
    TUTTE_LE_DATE.append(curr)
    curr += timedelta(days=1)

for dt in TUTTE_LE_DATE:
    dt_str = dt.strftime("%Y-%m-%d")
    wd = dt.weekday() # 4=Venerdì, 5=Sabato, 6=Domenica
    giorno = dt.day
    mese = dt.month

    # --- APRILE & MAGGIO & INIZIO GIUGNO (Fino al 2 Giugno) ---
    if dt < datetime(2026, 6, 5):
        if dt_str in ["2026-04-25", "2026-04-26"]:
            # Aprile: Sabato 25 e domenica 26 (10:00 - 20:00 ogni 30')
            inserisci_corse(navetto_calendario, dt_str, "65", genera_intervallo("10:00", "20:00", 30))
            inserisci_corse(navetto_calendario, dt_str, "66", genera_intervallo("10:00", "20:00", 30))
            
        elif dt_str in ["2026-05-01", "2026-05-31", "2026-06-01"]:
            # Orari Speciali Festivi (09:00 - 22:00)
            # 65: ogni 15' fino alle 20, poi 30'. 66: ogni 15' fino alle 20, poi 30'
            corse_65 = genera_intervallo("09:00", "20:00", 15) + genera_intervallo("20:00", "22:00", 30)
            corse_66 = genera_intervallo("09:00", "20:00", 15) + genera_intervallo("20:00", "22:00", 30)
            inserisci_corse(navetto_calendario, dt_str, "65", corse_65)
            inserisci_corse(navetto_calendario, dt_str, "66", corse_66)
            
        elif dt_str in ["2026-05-02", "2026-05-03", "2026-05-09", "2026-05-10", "2026-05-16", "2026-05-17", "2026-05-23", "2026-05-24", "2026-05-30"]:
            # Sabati e Domeniche Ordinari di Maggio (09:00 - 22:00)
            corse = genera_intervallo("09:00", "20:00", 15) + genera_intervallo("20:00", "22:00", 30)
            # NOTA: Il 2 Maggio da PDF fa 09:00 - 02:00. Gestiamo la notte qui sotto:
            if dt_str == "2026-05-02":
                corse = genera_intervallo("09:00", "20:00", 15) + genera_intervallo("20:00", "23:30", 30)
                # Le corse dalle 00:00 alle 02:00 vanno al 3 Maggio
                corse_notturne = genera_intervallo("00:00", "02:00", 30)
                inserisci_corse(navetto_calendario, "2026-05-03", "65", corse_notturne)
                inserisci_corse(navetto_calendario, "2026-05-03", "66", corse_notturne)
            
            inserisci_corse(navetto_calendario, dt_str, "65", corse)
            inserisci_corse(navetto_calendario, dt_str, "66", corse)
            
        elif dt_str == "2026-06-02":
            # Martedì 2 Giugno: 65 ogni 12' fino alle 20, poi 30'. 66 ogni 15' fino alle 20, poi 30'. (Fino alle 22:00)
            corse_65 = genera_intervallo("09:00", "20:00", 12) + genera_intervallo("20:00", "22:00", 30)
            corse_66 = genera_intervallo("09:00", "20:00", 15) + genera_intervallo("20:00", "22:00", 30)
            inserisci_corse(navetto_calendario, dt_str, "65", corse_65)
            inserisci_corse(navetto_calendario, dt_str, "66", corse_66)

    # --- REGIME ESTIVO DAL 5 GIUGNO IN POI ---
    else:
        # Escludiamo le eccezioni specifiche che gestiamo dopo
        ECCEZIONI = ["2026-06-09", "2026-06-10", "2026-06-11", "2026-06-19", "2026-06-20", 
                     "2026-07-22", "2026-07-23", "2026-08-29"]
        
        if mese == 8 and giorno in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 30]:
            pass # Gestito nel blocco speciale di Agosto
        elif dt_str in ECCEZIONI:
            pass # Gestito nel blocco eccezioni
        else:
            # Weekend standard estivi (Giugno, Luglio, Settembre)
            if wd == 4: # Venerdì
                # 12:00 - 02:00 ogni 30 minuti. Le corse 00:00-02:00 vanno al Sabato
                inserisci_corse(navetto_calendario, dt_str, "65", genera_intervallo("12:00", "23:30", 30))
                inserisci_corse(navetto_calendario, dt_str, "66", genera_intervallo("12:00", "23:30", 30))
                
                prossimo_giorno = (dt + timedelta(days=1)).strftime("%Y-%m-%d")
                inserisci_corse(navetto_calendario, prossimo_giorno, "65", genera_intervallo("00:00", "02:00", 30))
                inserisci_corse(navetto_calendario, prossimo_giorno, "66", genera_intervallo("00:00", "02:00", 30))
                
            elif wd == 5: # Sabato
                # 09:00 - 02:00 ogni 15 minuti. Le corse 00:00-02:00 vanno alla Domenica
                inserisci_corse(navetto_calendario, dt_str, "65", genera_intervallo("09:00", "23:45", 15))
                inserisci_corse(navetto_calendario, dt_str, "66", genera_intervallo("09:00", "23:45", 15))
                
                prossimo_giorno = (dt + timedelta(days=1)).strftime("%Y-%m-%d")
                inserisci_corse(navetto_calendario, prossimo_giorno, "65", genera_intervallo("00:00", "02:00", 15))
                inserisci_corse(navetto_calendario, prossimo_giorno, "66", genera_intervallo("00:00", "02:00", 15))
                
            elif wd == 6: # Domenica
                # 09:00 - 22:00 ordinario (Settembre) o 09:00-00:00 (Luglio)
                fine_orario = "00:00" if mese == 7 else "22:00"
                # Se è luglio ha frequenza 12' diurna per L65
                if mese == 7:
                    c_65 = genera_intervallo("09:00", "20:00", 12) + genera_intervallo("20:00", "23:30", 30)
                    c_66 = genera_intervallo("09:00", "20:00", 15) + genera_intervallo("20:00", "23:30", 30)
                    # La corsa delle 00:00 va al lunedì
                    inserisci_corse(navetto_calendario, (dt + timedelta(days=1)).strftime("%Y-%m-%d"), "65", ["00:00"])
                    inserisci_corse(navetto_calendario, (dt + timedelta(days=1)).strftime("%Y-%m-%d"), "66", ["00:00"])
                else: # Settembre
                    c_65 = genera_intervallo("09:00", "20:00", 15) + genera_intervallo("20:00", "22:00", 30)
                    c_66 = genera_intervallo("09:00", "20:00", 15) + genera_intervallo("20:00", "22:00", 30)
                
                inserisci_corse(navetto_calendario, dt_str, "65", c_65)
                inserisci_corse(navetto_calendario, dt_str, "66", c_66)

# 2. GESTIONE ECCEZIONI MIRATE (Inclusi spostamenti post-mezzanotte)

# 9-10-11 Giugno: Solo Linea 65, 20:00 - 02:00 ogni 30'. (00:00-02:00 slitta al mattino dopo)
for g_giugno in ["2026-06-09", "2026-06-10", "2026-06-11"]:
    inserisci_corse(navetto_calendario, g_giugno, "65", genera_intervallo("20:00", "23:30", 30))
    g_successivo = datetime.strptime(g_giugno, "%Y-%m-%d") + timedelta(days=1)
    inserisci_corse(navetto_calendario, g_successivo.strftime("%Y-%m-%d"), "65", genera_intervallo("00:00", "02:00", 30))

# Venerdì 19 Giugno: Notte Rosa. 12:00 - 02:00 ogni 30' fino alle 20, poi ogni 15'
v_19_serali = genera_intervallo("12:00", "20:00", 30) + genera_intervallo("20:00", "23:45", 15)
inserisci_corse(navetto_calendario, "2026-06-19", "65", v_19_serali)
inserisci_corse(navetto_calendario, "2026-06-19", "66", v_19_serali)
inserisci_corse(navetto_calendario, "2026-06-20", "65", genera_intervallo("00:00", "02:00", 15))
inserisci_corse(navetto_calendario, "2026-06-20", "66", genera_intervallo("00:00", "02:00", 15))

# Sabato 20 Giugno: 09:00 - 04:00. L65 diurna ogni 12' (14-20). Notte fino alle 04:00 (slitta al 21)
s_20_serali_65 = genera_intervallo("09:00", "14:00", 15) + genera_intervallo("14:00", "20:00", 12) + genera_intervallo("20:00", "23:45", 15)
s_20_serali_66 = genera_intervallo("09:00", "23:45", 15)
inserisci_corse(navetto_calendario, "2026-06-20", "65", s_20_serali_65)
inserisci_corse(navetto_calendario, "2026-06-20", "66", s_20_serali_66)
inserisci_corse(navetto_calendario, "2026-06-21", "65", genera_intervallo("00:00", "04:00", 15))
inserisci_corse(navetto_calendario, "2026-06-21", "66", genera_intervallo("00:00", "04:00", 15))

# Mercoledì 22 e Giovedì 23 Luglio: 12:00 - 02:00 (30' fino a 20, poi 15')
for g_luglio in ["2026-07-22", "2026-07-23"]:
    l_serali = genera_intervallo("12:00", "20:00", 30) + genera_intervallo("20:00", "23:45", 15)
    inserisci_corse(navetto_calendario, g_luglio, "65", l_serali)
    inserisci_corse(navetto_calendario, g_luglio, "66", l_serali)
    g_successivo = datetime.strptime(g_luglio, "%Y-%m-%d") + timedelta(days=1)
    inserisci_corse(navetto_calendario, g_successivo.strftime("%Y-%m-%d"), "65", genera_intervallo("00:00", "02:00", 15))
    inserisci_corse(navetto_calendario, g_successivo.strftime("%Y-%m-%d"), "66", genera_intervallo("00:00", "02:00", 15))

# --- BLOCCO AGOSTO ---
# Giorni a termine ore 00:00 (1, 9, 10, 11, 12, 13, 16, 22 agosto)
for d in [1, 9, 10, 11, 12, 13, 16, 22]:
    dt_s = f"2026-08-{d:02d}"
    c_65 = genera_intervallo("09:00", "20:00", 12) + genera_intervallo("20:00", "23:30", 30)
    c_66 = genera_intervallo("09:00", "20:00", 15) + genera_intervallo("20:00", "23:30", 30)
    inserisci_corse(navetto_calendario, dt_s, "65", c_65)
    inserisci_corse(navetto_calendario, dt_s, "66", c_66)
    inserisci_corse(navetto_calendario, f"2026-08-{(d+1):02d}", "65", ["00:00"])
    inserisci_corse(navetto_calendario, f"2026-08-{(d+1):02d}", "66", ["00:00"])

# Domeniche d'Agosto a termine ore 00:00 (2, 23, 30 agosto)
for d in [2, 23, 30]:
    dt_s = f"2026-08-{d:02d}"
    c_65 = genera_intervallo("09:00", "20:00", 12) + genera_intervallo("20:00", "23:30", 30)
    c_66 = genera_intervallo("09:00", "20:00", 15) + genera_intervallo("20:00", "23:30", 30)
    inserisci_corse(navetto_calendario, dt_s, "65", c_65)
    inserisci_corse(navetto_calendario, dt_s, "66", c_66)
    if d != 30: # Il 31 agosto non è attivo il servizio
        inserisci_corse(navetto_calendario, f"2026-08-{(d+1):02d}", "65", ["00:00"])
        inserisci_corse(navetto_calendario, f"2026-08-{(d+1):02d}", "66", ["00:00"])

# Feriali d'Agosto fino alle 02:00 (3, 4, 5, 6, 7, 17, 18, 19, 20, 21, 28 agosto)
for d in [3, 4, 5, 6, 7, 17, 18, 19, 20, 21, 28]:
    dt_s = f"2026-08-{d:02d}"
    inserisci_corse(navetto_calendario, dt_s, "65", genera_intervallo("12:00", "23:45", 15))
    inserisci_corse(navetto_calendario, dt_s, "66", genera_intervallo("12:00", "23:45", 15))
    inserisci_corse(navetto_calendario, f"2026-08-{(d+1):02d}", "65", genera_intervallo("00:00", "02:00", 15))
    inserisci_corse(navetto_calendario, f"2026-08-{(d+1):02d}", "66", genera_intervallo("00:00", "02:00", 15))

# Picco di ferragosto fino alle 04:00 (8, 14, 15 agosto)
for d in [8, 14, 15]:
    dt_s = f"2026-08-{d:02d}"
    c_65 = genera_intervallo("09:00", "14:00", 15) + genera_intervallo("14:00", "20:00", 12) + genera_intervallo("20:00", "23:45", 15)
    inserisci_corse(navetto_calendario, dt_s, "65", c_65)
    inserisci_corse(navetto_calendario, dt_s, "66", genera_intervallo("09:00", "23:45", 15))
    inserisci_corse(navetto_calendario, f"2026-08-{(d+1):02d}", "65", genera_intervallo("00:00", "04:00", 15))
    inserisci_corse(navetto_calendario, f"2026-08-{(d+1):02d}", "66", genera_intervallo("00:00", "04:00", 15))

# Sabato 29 Agosto: fino alle 02:00 ogni 15 minuti
inserisci_corse(navetto_calendario, "2026-08-29", "65", genera_intervallo("09:00", "23:45", 15))
inserisci_corse(navetto_calendario, "2026-08-29", "66", genera_intervallo("09:00", "23:45", 15))
inserisci_corse(navetto_calendario, "2026-08-30", "65", genera_intervallo("00:00", "02:00", 15))
inserisci_corse(navetto_calendario, "2026-08-30", "66", genera_intervallo("00:00", "02:00", 15))


# Pulizia: rimuove le giornate vuote generate per errore al di fuori del calendario reale attivo
navetto_calendario = {k: v for k, v in navetto_calendario.items() if k <= "2026-09-13"}

# Salvataggio su file JSON ordinato
with open("navettomare_orari_2026.json", "w") as f:
    json.dump(navetto_calendario, f, indent=2, sort_keys=True)

print("Nuovo file JSON generato con successo e senza orari oltre le 24 ore!")