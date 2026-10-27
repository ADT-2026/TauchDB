# TauchDB – DiveManager

**Datenbankgestütztes Verwaltungssystem für eine Tauchschule**

Hochschulprojekt im Modul **Advanced Databases**.

DiveManager bildet die zentralen Verwaltungsprozesse einer Tauchschule in einer relationalen PostgreSQL-Datenbank ab. Der Schwerpunkt liegt auf Datenmodellierung, referenzieller Integrität, Transaktionssicherheit und der Umsetzung komplexer Geschäftsregeln.

## 1. Projektüberblick

Das System unterstützt die Verwaltung von Kunden, Tauchlehrern, Zertifizierungen, Tauchkursen, Tauchausflügen, Ausrüstungsgegenständen, Wartungen, Vermietungen und Rechnungen.

**Technologien:**
- PostgreSQL als relationales Datenbankmanagementsystem
- Prisma ORM 7 zur Definition des Datenmodells und Verwaltung der Migrationen
- Supabase für die PostgreSQL-Entwicklungsumgebung
- Docker zur lokalen Bereitstellung
- SQL, PL/pgSQL, Trigger und Constraints zur Sicherstellung der Datenintegrität

**Aktueller Datenbankentwurf:** 16 relationale Tabellen.

Eine vollständige Benutzeroberfläche ist derzeit nicht Bestandteil des primären Projektumfangs.

## 2. Datenbankmodell

Das Datenmodell umfasst folgende 16 Tabellen:

| Tabelle | Beschreibung |
|---|---|
| `customers` | Kundenstammdaten |
| `instructors` | Tauchlehrer |
| `certifications` | Zertifizierungstypen |
| `customer_certifications` | Zertifizierungen von Kunden |
| `instructor_certifications` | Qualifikationen der Tauchlehrer |
| `courses` | Kursarten, Preise und Voraussetzungen |
| `course_sessions` | Konkrete Kurstermine |
| `dive_sites` | Tauchplätze |
| `dive_trips` | Organisierte Tauchausflüge |
| `bookings` | Kurs- und Ausflugsbuchungen |
| `equipment` | Ausrüstungsinventar |
| `equipment_allocations` | Zentrale zeitliche Ausrüstungsbelegungen |
| `equipment_rentals` | Ausrüstungsvermietungen |
| `equipment_assignments` | Ausrüstungszuweisungen zu Buchungen |
| `equipment_maintenance` | Wartungs- und Reparaturvorgänge |
| `invoices` | Rechnungen |

### Zentrale Modellierungsentscheidungen

**Einheitliche Buchungen:** Kursbuchungen und Ausflugsanmeldungen werden in der Tabelle `bookings` verwaltet. Jede Buchung gehört genau zu einem Kurstermin oder Tauchausflug.

**Zentrale Ausrüstungsverwaltung:** Die Tabelle `equipment_allocations` verwaltet zeitliche Belegungen für Vermietung, Buchungszuweisung und Wartung. Die jeweiligen Detailinformationen befinden sich in separaten Tabellen.

**Zertifizierungsverwaltung:** Zertifikate von Kunden und Tauchlehrern werden getrennt gespeichert. Für Kurse und Tauchplätze können erforderliche Zertifizierungen hinterlegt werden.

**Rechnungsstellung:** Rechnungen werden genau einer Buchung oder einer Ausrüstungsmiete zugeordnet. Das Modell unterstützt derzeit einzelne Rechnungen pro Leistung und bildet einen Zahlungszeitpunkt über `paid_at` ab.

## 3. Datenintegrität und Geschäftsregeln

Das Datenbankschema verwendet Primärschlüssel, Fremdschlüssel, UNIQUE-Indizes und CHECK-Constraints. Zusätzlich werden PostgreSQL-spezifische Mechanismen zur Sicherstellung komplexerer Geschäftsregeln eingesetzt.

### 3.1 Buchungsverwaltung

Die SQL-Migration enthält einen Trigger, der bei der Erstellung und bei bestimmten Änderungen von Buchungen die zulässige Teilnehmerkapazität überprüft.

Außerdem wird kontrolliert, ob ein Kunde zum Beginn der Veranstaltung über die erforderliche gültige Zertifizierung verfügt.

Partielle UNIQUE-Indizes verhindern, dass ein Kunde denselben Kurstermin oder Tauchausflug mehrfach aktiv bucht. Nach einer Stornierung kann eine neue Buchung ermöglicht werden.

### 3.2 Verfügbarkeit von Tauchlehrern

Die Datenbank verhindert zeitliche Überschneidungen innerhalb der Kurstermine beziehungsweise innerhalb der Tauchausflüge mithilfe von Exclusion-Constraints.

Ein zusätzlicher Trigger prüft Überschneidungen zwischen Kursen und Tauchausflügen, damit ein Tauchlehrer nicht zeitgleich für verschiedene Veranstaltungen eingeplant wird.

### 3.3 Ausrüstungsbelegung

Für `equipment_allocations` wird ein PostgreSQL-Exclusion-Constraint eingesetzt.

Dadurch dürfen für denselben Ausrüstungsgegenstand keine zeitlich überlappenden, nicht stornierten Belegungen entstehen.

Die Detailtabellen `equipment_rentals`, `equipment_assignments` und `equipment_maintenance` verwenden typgebundene Fremdschlüssel und CHECK-Constraints, um ihre Zuordnung zu passenden Belegungen abzusichern.

### 3.4 Rechnungsverwaltung

Jede Rechnung muss genau einer kostenpflichtigen Leistung zugeordnet sein: entweder einer Buchung oder einer Ausrüstungsmiete.

Ein CHECK-Constraint mit `num_nonnulls(booking_id, rental_id) = 1` erzwingt diese Regel.

Zusätzlich überprüft ein Trigger, ob der Rechnungskunde mit dem Kunden der zugehörigen Buchung oder Miete übereinstimmt.

### 3.5 Weitere Integritätsregeln

Das Datenbankschema enthält unter anderem Prüfungen für:

- positive Teilnehmerkapazitäten,
- gültige Zeitintervalle,
- nichtnegative Preise und Kosten,
- konsistente Zertifikats- und Rechnungsdaten,
- case-insensitive eindeutige E-Mail-Adressen,
- zeitlich überschneidende Kundenzertifikate.

Row Level Security (RLS) ist für die Tabellen aktiviert. Eigene RLS-Policies für direkte Client-Zugriffe sind in den aktuellen Migrationen noch nicht definiert.

## 4. Projektstruktur

```text
TauchDB/
├── README.md
└── db/
    ├── prisma/
    │   ├── schema.prisma
    │   └── migrations/
    │       ├── 20261027162418_init/
    │       └── 20261027162424_constraints_and_triggers/
    ├── prisma7.config.ts
    ├── package.json
    ├── package-lock.json
    └── supabase/
        ├── config.toml
        ├── Initial_Setup.md
        └── Supabase_Usage.md
```

Das verbindliche Prisma-Datenmodell befindet sich in `db/prisma/schema.prisma`.

Die SQL-Migrationen enthalten zusätzliche Constraints und Trigger, die nicht vollständig durch Prisma selbst dargestellt werden können.

## 5. Lokale Entwicklungsumgebung

### Voraussetzungen

- Node.js 20 oder neuer
- npm
- Docker Desktop

### Installation

Repository klonen:

```bash
git clone https://github.com/ADT-2026/TauchDB.git
cd TauchDB/db
```

Abhängigkeiten installieren:

```bash
npm install
```

Lokale Supabase-Umgebung starten:

```bash
npx supabase start
```

Verbindungsinformationen anzeigen:

```bash
npx supabase status
```

Eine lokale Datei `db/.env` mit den benötigten Datenbankverbindungen anlegen. Die Prisma-Konfiguration verwendet `DIRECT_URL`.

Für das standardmäßige lokale Supabase-Setup kann folgende Konfiguration verwendet werden:

```dotenv
DIRECT_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres"
DATABASE_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres"
```

**Wichtig:** Echte Zugangsdaten und `.env`-Dateien dürfen nicht in Git eingecheckt werden.

### Datenbankschema anwenden

```bash
npx prisma validate
npx prisma migrate deploy
npx prisma migrate status
```

Die Befehle aus dem Verzeichnis `db/` ausführen.

Die Migrationen sind für das aktuelle 16-Tabellen-Schema ausgelegt. Bei bestehenden Datenbanken ist vor der Anwendung eine Prüfung der bisherigen Struktur und des Migrationsverlaufs erforderlich.

Weitere Informationen befinden sich unter `db/supabase/Initial_Setup.md` und `db/supabase/Supabase_Usage.md`.

## 6. Aktueller Implementierungsstand

**Im Repository vorhanden:**
- Prisma-Datenmodell mit 16 Tabellen
- Initialmigration für PostgreSQL
- Erweiterte CHECK-Constraints
- UNIQUE-Indizes und Fremdschlüssel
- Exclusion-Constraints für zeitliche Überschneidungen
- Trigger für Buchungskapazitäten und Zertifizierungsvoraussetzungen
- Trigger für die Verfügbarkeit von Tauchlehrern
- Trigger für die Kundenkonsistenz bei Rechnungen
- Aktivierung von Row Level Security

**Noch zu prüfen beziehungsweise zu erweitern:**
- Kapazitätskontrolle bei nachträglicher Änderung der maximalen Teilnehmerzahl
- Zwingende Detailzuordnung für jede Ausrüstungsbelegung
- Qualifikationsprüfung bei der Zuweisung von Tauchlehrern
- Absicherung nachträglicher Änderungen an bereits abgerechneten Leistungen
- Automatisierte Tests der Integritätsregeln und konkurrierender Transaktionen
- Kontrollierte Übernahme des Schemas in die gemeinsame Zielumgebung

Die Versionierung einer Migration belegt noch nicht, dass sie bereits auf jeder Ziel-Datenbank erfolgreich ausgeführt und getestet wurde.

## 7. Weitere Projektphasen

### Thema 1 – Datenbankwahl und Modellierung

Entscheidung für PostgreSQL, Modellierung und Implementierung des relationalen Schemas sowie Umsetzung grundlegender und erweiterter Datenbankconstraints.

### Thema 2 – Testdatengenerierung

Erstellung geeigneter synthetischer Testdaten zur Untersuchung des Datenbankverhaltens.

### Thema 3 – Last- und Performanceuntersuchungen

Durchführung und Auswertung von Lasttests, SQL-Abfragen und datenbankbezogenen Performanceanalysen.

Die Arbeiten an Thema 2 und Thema 3 sind eigenständige spätere Projektphasen.

## 8. Weiterführende Projektdateien

- [Prisma-Schema](db/prisma/schema.prisma)
- [Initialmigration](db/prisma/migrations/20261027162418_init/migration.sql)
- [Constraints und Trigger](db/prisma/migrations/20261027162424_constraints_and_triggers/migration.sql)
- [Lokale Einrichtung](db/supabase/Initial_Setup.md)
- [Supabase-Anwendung](db/supabase/Supabase_Usage.md)

---

**Projekt:** DiveManager / TauchDB  
**Modul:** Advanced Databases  
**Datenbank:** PostgreSQL  
**Aktueller Schemaumfang:** 16 Tabellen
