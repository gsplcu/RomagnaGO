# Genera il grafo stradale RomagnaGO (GraphHopper foot)
#
# Prerequisiti:
#   - Java JDK 17+  (java -version)
#   - Docker Desktop (consigliato per ritagliare OSM)  OPPURE  osmium-tool
#   - ~6 GB RAM liberi, ~2 GB spazio disco
#
# Uso (PowerShell, dalla root del repo):
#   .\tool\graphhopper\build_romagna_graph.ps1
#
# Output:
#   tool\graphhopper\romagna-gh\     (cartella grafo)
#   assets\graphhopper\romagna.ghz   (zip per l'APK)
#
# Poi aggiungi in pubspec.yaml sotto flutter/assets:
#   - assets/graphhopper/romagna.ghz
#
# Riavvia l'app (flutter run). Al primo avvio il grafo viene estratto in storage interno.

$ErrorActionPreference = "Stop"
$Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $PSScriptRoot

$GhVersion = "8.0"
$GhJar = "graphhopper-web-$GhVersion.jar"
$GhUrl = "https://github.com/graphhopper/graphhopper/releases/download/$GhVersion/$GhJar"
$OsmFull = "emilia-romagna-latest.osm.pbf"
$OsmUrl = "https://download.geofabrik.de/europe/italy/emilia-romagna-latest.osm.pbf"
$OsmClip = "romagna.osm.pbf"
$GraphDir = "romagna-gh"
$OutZip = Join-Path $Root "assets\graphhopper\romagna.ghz"

# Bbox RomagnaGO (allineato a Nominatim)
$Bbox = "11.70,43.62,12.75,44.48"

Write-Host "== GraphHopper RomagnaGO foot graph ==" -ForegroundColor Cyan

if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
  throw "Java 17+ non trovato. Installa JDK 17 e aggiungilo al PATH."
}

if (-not (Test-Path $GhJar)) {
  Write-Host "Download GraphHopper $GhJar ..."
  Invoke-WebRequest -Uri $GhUrl -OutFile $GhJar
}

if (-not (Test-Path $OsmClip)) {
  if (-not (Test-Path $OsmFull)) {
    Write-Host "Download OSM Emilia-Romagna (~250 MB, una tantum) ..."
    Invoke-WebRequest -Uri $OsmUrl -OutFile $OsmFull
  }
  Write-Host "Ritaglio bbox RomagnaGO ..."
  $docker = Get-Command docker -ErrorAction SilentlyContinue
  if ($docker) {
    docker run --rm -v "${PWD}:/data" osmcode/osmium-tool `
      osmium extract -b $Bbox "/data/$OsmFull" -o "/data/$OsmClip" --overwrite
  } else {
    throw @"
Docker non trovato. Per ritagliare l'OSM alla Romagna serve uno di:
  1) Docker Desktop, poi rilancia questo script
  2) osmium-tool (https://osmcode.org/osmium-tool/) e comando:
     osmium extract -b $Bbox $OsmFull -o $OsmClip --overwrite
"@
  }
}

if (Test-Path $GraphDir) {
  Write-Host "Rimozione grafo precedente ..."
  Remove-Item -Recurse -Force $GraphDir
}

Write-Host "Import GraphHopper (5-20 minuti) ..."
java -Xmx4g -jar $GhJar import config-romagna-foot.yml

if (-not (Test-Path (Join-Path $GraphDir "properties"))) {
  throw "Import fallito: manca $GraphDir\properties"
}

Write-Host "Creazione romagna.ghz ..."
$AssetDir = Join-Path $Root "assets\graphhopper"
New-Item -ItemType Directory -Force -Path $AssetDir | Out-Null
if (Test-Path $OutZip) { Remove-Item -Force $OutZip }
Compress-Archive -Path (Join-Path $GraphDir "*") -DestinationPath $OutZip

Write-Host ""
Write-Host "Fatto." -ForegroundColor Green
Write-Host "  Grafo:  $PSScriptRoot\$GraphDir"
Write-Host "  Asset:  $OutZip"
Write-Host ""
Write-Host "Prossimi passi:" -ForegroundColor Yellow
Write-Host "  1. Aggiungi in pubspec.yaml:  - assets/graphhopper/romagna.ghz"
Write-Host "  2. flutter pub get"
Write-Host "  3. flutter run  (stop completo, non solo hot reload)"
