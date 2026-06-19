# Grafo GraphHopper per RomagnaGO (routing a piedi offline)

L’app usa GraphHopper **solo su Android**, profilo **foot**, area **RomagnaGO** (stessi confini della ricerca indirizzi).

Senza il file `romagna.ghz` l’app **non crasha**: resta il calcolo a piedi in linea d’aria come prima.

---

## Cosa ti serve sul PC (una tantum)

| Requisito | Note |
|-----------|------|
| **Java JDK 17+** | `java -version` in PowerShell |
| **Docker Desktop** | Consigliato per ritagliare la mappa OSM alla Romagna |
| **~6 GB RAM** | Durante l’import |
| **~2 GB disco** | OSM + grafo + zip |

---

## Passi (Windows)

### 1. Verifica Java

```powershell
java -version
```

Deve essere 17 o superiore. Se manca: installa [Eclipse Temurin 17](https://adoptium.net/) e riapri il terminale.

### 2. Verifica Docker (consigliato)

```powershell
docker --version
```

Se Docker non c’è, installa [Docker Desktop](https://www.docker.com/products/docker-desktop/) e avvialo.

### 3. Genera il grafo

Dalla **root del progetto** RomagnaGO:

```powershell
.\tool\graphhopper\build_romagna_graph.ps1
```

Lo script:

1. Scarica GraphHopper 8.0 (JAR) se manca  
2. Scarica OSM Emilia-Romagna da Geofabrik (~250 MB, solo la prima volta)  
3. Ritaglia al bbox RomagnaGO con Docker + Osmium  
4. Importa il grafo pedonale (5–20 minuti)  
5. Crea `assets\graphhopper\romagna.ghz`

### 4. Registra l’asset in Flutter

Apri `pubspec.yaml` e, nella sezione `flutter: assets:`, aggiungi:

```yaml
    - assets/graphhopper/romagna.ghz
```

Poi:

```powershell
flutter pub get
```

### 5. Ricompila l’app

Stop completo di `flutter run`, poi:

```powershell
flutter run
```

Al **primo avvio** su telefono/emulatore il grafo viene estratto dall’APK (può richiedere 20–60 secondi). I successivi avvii sono più veloci.

---

## Come capire se funziona

1. Tab **Percorso** → calcola un tragitto corto (es. due indirizzi in Cesena).  
2. Apri il dettaglio: le tratte **a piedi** devono seguire le strade (non più un segmento retto).  
3. In debug console: `GraphHopperWalkService: init ok`.

Se vedi ancora linee rette: manca `romagna.ghz` in pubspec o non hai fatto restart completo.

---

## Risoluzione problemi

| Problema | Soluzione |
|----------|-----------|
| Script: Docker non trovato | Installa Docker Desktop oppure installa [osmium-tool](https://osmcode.org/osmium-tool/) e ritaglia a mano (vedi script) |
| `init fallita` in log | Controlla che `romagna.ghz` sia in pubspec e che il file esista in `assets/graphhopper/` |
| APK enorme | Normale con grafo incluso; il bbox Romagna è più piccolo dell’intera ER |
| Build Android fallisce su Java | Android Studio / Gradle usa Java 17 (già impostato in `android/app/build.gradle.kts`) |

---

## File generati (non committare tutto)

In `.gitignore` sono ignorati OSM e grafi pesanti. In repo restano script e `LEGGIMI.txt`; tu aggiungi localmente `romagna.ghz` quando pronto.

Versione GraphHopper: **8.0** (deve coincidere tra script import e dipendenza Android).
