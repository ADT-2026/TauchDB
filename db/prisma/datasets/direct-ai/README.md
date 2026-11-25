# KI-SQL-Beispieldatensatz

`seed.sql` enthält den korrigierten, direkt mit KI erzeugten Beispielbestand:
**578 Zeilen in 16 Tabellen**, Stichtag **22.11.2026**. Es ist ein fester
synthetischer Datensatz für Tests und Demonstrationen.

## Import

Voraussetzung ist eine isolierte Testdatenbank mit den beiden Migrationen vom
09.11.2026 und leeren Fachtabellen. Aus dem Verzeichnis `db`:

```bash
psql -X "$TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f prisma/datasets/direct-ai/seed.sql
psql -X "$TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f prisma/datasets/direct-ai/verify.sql
```

Der Import läuft in einer Transaktion, lässt Constraints und Trigger aktiv und
setzt die ID-Sequenzen passend zum Bestand. Vorhandene Daten werden nicht
gelöscht; bei befüllten Fachtabellen wird der Import abgelehnt.

## Prüfung

`verify.sql` prüft diesen konkreten Bestand: Zeilenzahlen, gültige
Kundenzertifikate, zeitliche Überschneidungen, Ausrüstungszeiträume,
Rechnungsbezüge und Beträge sowie Veranstaltungskapazitäten. Zusätzlich werden
ein vollständig belegter und ein leerer Termin, ein Zertifikat mit Ablauf am
Veranstaltungstag und direkt anschließende Ausrüstungsbelegungen geprüft.

Die Prüfung verändert keine gespeicherten Daten. Ihre festen Mengen und
Szenario-IDs gelten ausschließlich für diesen Datensatz; für andere Bestände
muss sie angepasst werden. Sie ersetzt keine vollständige fachliche Prüfung
oder Lasttests.
