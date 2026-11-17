# Massendaten mit KI

Eine Bewertung nach Realismus, Korrektheit, Edge Cases, Constraints, Anzahl,
Erstellungsaufwand, Schemaänderungen und Coverage steht in der
[Analyse der KI-Testdaten](AI_Massendaten_Analyse.md).

Dieser Versuch verwendet ein **von KI geschriebenes SQL-Skript**. PostgreSQL erzeugt die
Datensätze durch Schleifen und feste Regeln. Es werden keine Datenbibliotheken wie Faker
und keine weiteren KI-Aufrufe zur Laufzeit benötigt. Das ist für die Projektauswertung
von direkt durch ein Sprachmodell ausgegebenen einzelnen JSON-/SQL-Datensätzen zu unterscheiden.

Die Namen, Angebote und Orte sind synthetisch. E-Mail-Adressen wie
`customer.1@ai-v1.example.invalid` dienen ausschließlich als Testwerte und sind keine
echten, zustellbaren Adressen. Telefonnummern bleiben leer.

## Lokal starten und importieren

Aus `db/`, mit laufendem Docker Desktop:

```sh
npm ci
npx supabase start
DIRECT_URL='postgresql://postgres:postgres@127.0.0.1:54322/postgres' npx prisma migrate deploy
npm run db:seed:ai
```

Der Import nutzt `psql` **im lokalen Supabase-Docker-Container**, daher ist keine lokale
`psql`-Installation notwendig. Der Standardname lautet `supabase_db_db`, passend zu
`project_id = "db"` in `supabase/config.toml`. Bei abweichendem Namen:

```sh
SUPABASE_DB_CONTAINER=supabase_db_meinprojekt npm run db:seed:ai
```

Der npm-Befehl verwendet keine `.env` oder `DIRECT_URL`. Er akzeptiert nur einen lokalen
Docker-Endpunkt mit Unix-Socket und arbeitet im ausgewählten Container in `postgres`.
Schemaänderungen erfolgen wie bisher über die Prisma-Migrationen.

Alternativ kann der Inhalt von [seed-ai.sql](seed-ai.sql) im SQL-Editor des **lokalen**
Supabase Studio ausgeführt werden, anschließend [check-ai.sql](check-ai.sql).
Studio ist unter <http://127.0.0.1:54323> erreichbar.

## Datensatz

Die Standardkonfiguration erzeugt:

| Bereich | Anzahl |
| --- | ---: |
| Kunden | 1.000 |
| Tauchlehrer | 10 |
| Zertifizierungstypen | 2 |
| Kundenzertifikate (Voraussetzungen und bestandene Kurse) | 1.363 |
| Lehrerzertifikate | 20 |
| Kursarten / Tauchplätze | je 3 |
| Kurstermine / Tauchausflüge | je 125 |
| Buchungen | 2.000 |
| davon storniert | 200 |
| Ausrüstungsgegenstände | 120 |
| Ausrüstungsmieten | 250 |
| Ausrüstungszuweisungen | 100 |
| Wartungen | 100 |
| Ausrüstungsbelegungen insgesamt | 450 |
| Rechnungen | 2.050 |
| **Zeilen insgesamt** | **7.721** |

Kundenzertifikate bilden sowohl Voraussetzungen als auch bestandene Kurse ab.
Alle 16 Tabellen werden befüllt. Der Prüfbefehl zeigt die tatsächlichen Zeilenzahlen
einschließlich Kundenzertifikaten und Gesamtsumme an.

Gruppen haben maximal acht Teilnehmer. Ihr Kurs und Ausflug finden in derselben Woche
an verschiedenen Tagen statt. Die Gruppen wechseln zwischen Anfängern, Open-Water-
und Advanced-Niveau. Lehrer und Ausrüstung werden ohne Zeitüberschneidung eingeplant.
Für stornierte Buchungen entstehen keine Rechnungen oder Ausrüstungszuweisungen.
Mieten sind eigenständige Leistungen mit eigenen Rechnungen. Ausgemusterte Artikel
werden nicht verplant. Enthalten sind bezahlte und offene Rechnungen, vergangene und
geplante Veranstaltungen sowie bestandene und noch nicht bestandene Kurse.

Der feste Stichtag ist **17.11.2026, 12:00 Uhr Europe/Berlin**; der erste Kurstag ist
05.01.2026. So bleiben die fachlichen Daten bei unveränderter Konfiguration reproduzierbar.
Die automatisch vergebenen IDs können sich je nach vorhandenen Daten unterscheiden.

## Bestehende Daten und Wiederholung

`seed-ai.sql` fügt Daten innerhalb einer Transaktion hinzu. Fremdschlüssel, CHECKs,
UNIQUE-/Exclusion-Constraints und Trigger bleiben aktiv; auch die verzögerten Prüfungen
der Ausrüstungsdetails werden vor dem Commit ausgeführt. Ein Fehler rollt den Import
zurück. PostgreSQL-Sequenzen können dabei trotzdem weiterzählen.

Bestehende Datensätze werden nicht gelöscht oder geändert. Der Namensraum `ai-v1`
kennzeichnet die neuen Daten. Eigene synthetische Zertifizierungstypen verhindern
Abhängigkeiten von vorhandenen Stammdaten. Ein zweiter Import desselben Namensraums
bricht vor dem Einfügen ab, anstatt Duplikate anzulegen.

Die wiederholbare Prüfung verändert nur temporäre Objekte:

```sh
npm run db:check:ai
```

Sie prüft Mengenverhältnisse, Kurs-/Tripzuordnung, gültige Voraussetzungen, Zeitfolgen,
Rechnungskunden und -beträge, Ausrüstungszuweisungen, Ausmusterung und Belegungsdetails.
Abweichungen führen zu einem Fehlercode. Der Import bleibt nach erfolgreichem Commit
auch dann bestehen, wenn die anschließende fachliche Prüfung einen Fehler meldet.

### Ergebnis des ersten lokalen Versuchs (17.11.2026)

Beide Prisma-Migrationen wurden auf die frische lokale Supabase-Datenbank angewendet.
Der Standardimport lief erfolgreich durch, einschließlich aller aktiven Constraints
und Trigger. Die Mengenprüfungen und alle neun fachlichen Prüfungen bestanden mit
null Abweichungen. Vorhanden sind 1.539 bezahlte und 511 offene Rechnungen.
Ein zweiter Import wurde erwartungsgemäß abgelehnt; die anschließende Prüfung
bestätigte unverändert 7.721 Zeilen. Der Versuch ist ein Funktions- und Integritätstest,
keine isolierte Performance-Messung.

PostgreSQL ist direkt unter `127.0.0.1:54322` erreichbar; `prisma migrate status`
bestätigt den aktuellen Migrationsstand. Studio ist nach dem ersten, verzögerten
Containerstart unter <http://127.0.0.1:54323> erreichbar.

**Nicht `npm run db:test` oder `npm run db:upload-seed` zum Prüfen dieses Datensatzes
verwenden:** Diese vorhandenen Befehle laden den kleinen Constraint-Testdatensatz
und leeren dabei die Fachtabellen.

## Größere Versuche und Vergleich

Für einen weiteren Versuch `customer_count` und `dataset` oben in `seed-ai.sql`
anpassen. In `check-ai.sql` entsprechend `dataset` anpassen. Mengenprüfungen werden
aus der tatsächlich vorhandenen Kundenzahl abgeleitet. Die Konfiguration begrenzt
die Kundenzahl auf 100.000. Größere Varianten sind nicht automatisch getestet.

Die Termine wachsen linear mit der Kundenzahl: zwei Achtergruppen pro Woche.
Bei sehr großen Varianten entsteht dadurch ein unrealistisch langer Zeitraum.
Für Lasttests mit festem Zeitraum müssten auch Lehrer und Ausrüstung mitskalieren.
Die Verteilungen sind bewusst regelmäßig und eignen sich als erster Integritäts-
und Importversuch, nicht als Beleg für realistische Produktionslast.

Für einen fairen Vergleich mit dem Library-Ansatz dieselben Tabellen, Kundenzahlen,
Verteilungen und Integritätsprüfungen verwenden. Sinnvolle Messwerte sind:

- Zeit für Erstellung und Korrektur des Generators;
- Importdauer bei gleicher lokaler Umgebung;
- Anzahl importierter Zeilen je Tabelle;
- Anzahl und Art abgelehnter Datensätze bzw. fachlicher Fehler;
- Vielfalt, Regelmäßigkeit und fachliche Plausibilität der Daten.

Dieser Versuch misst die SQL-Ausführung eines KI-erstellten Generators. Er misst
keine laufende KI-Inferenz oder direkte Generierung jedes einzelnen Datensatzes.

## Folgeprompt zur Reproduktion oder Erweiterung

> Erstelle für das beiliegende Prisma-Schema und beide SQL-Migrationen von TauchDB
> ein PostgreSQL-Skript für 1.000 synthetische Kunden und zusammenhängende Daten
> in allen 16 Tabellen. Berücksichtige Zertifikatsvoraussetzungen, Achtergruppen,
> stornierte Buchungen, Lehrer- und Ausrüstungsverfügbarkeit, typgebundene
> Ausrüstungsdetails sowie korrekte Rechnungszuordnungen. Nutze einen festen
> Stichtag 17.11.2026 Europe/Berlin, synthetische E-Mails unter example.invalid,
> keine Datenbibliotheken, keine deaktivierten Constraints und kein Löschen
> vorhandener Daten. Verwende einen eigenen Datensatznamensraum und normale
> Datenbanksequenzen. Ergänze wiederholbare Mengen- und Plausibilitätsprüfungen.

Als Kontext müssen `schema.prisma` und die beiden `migration.sql`-Dateien mitgegeben
werden: Das Prisma-Schema allein enthält nicht alle Integritätsregeln.
