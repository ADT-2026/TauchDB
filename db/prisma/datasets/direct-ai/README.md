# Direkt mit KI erzeugte Beispieldaten

`seed.sql` ist die korrigierte Fassung der ursprünglich direkt mit KI erzeugten SQL-Beispieldaten. Der Bestand ist vom SQL-Generator `prisma/seed-ai.sql` und dessen Namensraum `ai-v1` unabhängig. Die Originaldateien waren vorher nicht im Repository enthalten.

Die korrigierte Fassung umfasst **578 Zeilen in 16 Tabellen**, Stichtag **22.11.2026**. Sie benötigt beide Originalmigrationen vom 09.11.2026. Der Import verlangt leere Fachtabellen, löscht keine vorhandenen Daten und lässt Constraints und Trigger aktiv. Ein zweiter Import wird mit einer verständlichen Fehlermeldung abgelehnt.

## Import und Prüfung

In einer isolierten, bereits migrierten Testdatenbank aus dem Verzeichnis `db`:

```bash
psql "$TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f prisma/datasets/direct-ai/seed.sql
psql "$TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f prisma/datasets/direct-ai/verify.sql
```

`verify.sql` prüft Mengen, Zertifikate, Buchungs- und Ausrüstungszeiten, Rechnungsbezüge, Beträge und die ergänzten Szenarien. Die feste Zeilenzahl gehört zu diesem konkreten Bestand; für andere Bestände muss die Mengenliste angepasst werden.

## Korrekturen

- Sechs überlappende Wiederholungseinträge von Kundenzertifikaten entfernt. Vorhandene unbefristete Qualifikationen bleiben erhalten.
- Fünf zusätzliche **synthetische** PADI-Nachweise für die Kunden 3, 6, 12 und 20 ergänzt. Dadurch erfüllen alle Buchungen die tatsächlich implementierte Prüfung auf eine konkrete Zertifikats-ID. Eine generelle Gleichwertigkeit zwischen Verbänden wird weder behauptet noch automatisch eingeführt.
- Alle Zeitangaben als beabsichtigte lokale Uhrzeiten in `Europe/Berlin` interpretiert und mit dem zum Datum passenden Sommer- oder Winterzeitoffset gespeichert.
- Drei Kunden ohne Buchung sowie einen weiteren Kunden für einen gezielten Zertifikatsgrenzfall ergänzt.
- Einen vollständig belegten und einen leeren geplanten Kurstermin ergänzt.
- Eine Buchung ergänzt, deren Zertifikat genau am Veranstaltungstag abläuft. Das inklusive Ablaufdatum ist nach dem vorhandenen Schema gültig.
- Zwei unmittelbar anschließende Ausrüstungsmieten ergänzt. `[Start, Ende)` lässt diesen Anschluss zu.
- Sequenzen auf die jeweils höchste tatsächlich verwendete ID gesetzt. Durch entfernte Originalzeilen sind Lücken in der ID-Folge beabsichtigt.

Die längeren Vor- und Nachbereitungszeiten vorhandener Ausrüstungszuweisungen und die historische Aufbewahrung stornierter Belegungen wurden erhalten. Sie waren keine Fehler.

## Originale und PDF

`original/tauchschule_beispieldaten.sql` und `original/tauchschule_beispieldaten.pdf` sind unveränderte Ausgangsartefakte. **Sie enthalten den früheren, nicht korrigierten Stand und dienen ausschließlich der Nachvollziehbarkeit.** Die PDF ist keine aktualisierte Darstellung von `seed.sql` und kein Prüfbericht. Für den Import ist ausschließlich die Datei `seed.sql` in diesem Ordner vorgesehen.

## Teststand

Der korrigierte Bestand wurde am 24.11.2026 unabhängig offline und in einer separaten PostgreSQL-17-Testdatenbank mit den aktiven Originalmigrationen importiert und geprüft. Die zugehörigen konkreten Ergebnisse stehen in `validation.json`.

Der Datensatz bleibt eine feste synthetische Beispielsammlung. Er liefert keine empirisch kalibrierte Nachfrageverteilung und ersetzt keine Lasttests. Diese Eigenschaften sind durch Datenkorrekturen allein nicht herstellbar.
