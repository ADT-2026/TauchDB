# Analyse der KI-Testdaten anhand der acht Kriterien

Stand: 17.11.2026. Bewertet wird ausschließlich der Datensatz `ai-v1` aus
`seed-ai.sql`. Die Analyse beruht auf dem Generator, dem Prisma-Schema, den
SQL-Migrationen und erneuten SQL-Abfragen gegen die lokale Supabase-Datenbank.
Die Analyseabfragen legten nur temporäre Objekte an; die Transaktion wurde
zurückgerollt. Die bestehenden Testdaten wurden nicht verändert.

Es handelt sich um einen **KI-erstellten SQL-Generator**: Die einzelnen Datenzeilen
entstehen durch PostgreSQL-Schleifen und feste Regeln. Aussagen über direkt vom
Sprachmodell ausgegebene JSON-Datensätze lassen sich daraus nicht ableiten.

| Kriterium | Bewertung | Zentrale Begründung |
| --- | --- | --- |
| Realismus und Komplexität | Mittlerer Realismus, gute relationale Komplexität | Alle Fachbereiche sind verknüpft; feste Regeln erzeugen jedoch starke künstliche Muster. |
| Korrektheit | Gut innerhalb der geprüften Regeln | Import mit aktiven Constraints erfolgreich; alle neun fachlichen Prüfungen weiterhin ohne Abweichung. |
| Edge Cases | Teilweise abgedeckt | Stornos, offene Rechnungen und Ausmusterung vorhanden; viele Grenz- und Fehlerfälle fehlen. |
| Constraints | Beim Import aktiv, Ablehnungsverhalten unvollständig getestet | Datenbank prüft gültige Inserts; daraus folgt kein vollständiger Negativtest aller Regeln. |
| Anzahl | Für den ersten Funktionstest passend | 1.000 Kunden und 7.721 Zeilen; noch kein Nachweis für Verhalten unter großer Last. |
| Aufwand der Erstellung | Nicht quantitativ bewertet | Keine getrennte Zeitmessung für Erstellung, Review, Einrichtung und Korrektur vorhanden. |
| Aufwand bei Schemaänderungen | Voraussichtlich mittel, bei Regeländerungen höher | Direkte SQL-Abhängigkeiten in Generator und Prüfer; kein Änderungsversuch durchgeführt. |
| Coverage | Vollständige Tabellenabdeckung, begrenzte Fallabdeckung | 16/16 Tabellen, aber mehrere Felder und Zustände sowie Fehler-, Änderungs- und Zugriffsfälle fehlen. |

## 1. Realismus und Komplexität

Positiv sind zusammenhängende Daten über Kunden, Zertifikate, Veranstaltungen,
Buchungen, Ausrüstungsbelegungen und Rechnungen. Voraussetzungen und zeitliche
Verfügbarkeit werden berücksichtigt. Enthalten sind 90 abgeschlossene und
35 geplante Kurstermine sowie ebenso viele abgeschlossene und geplante Ausflüge.
Von 2.050 Rechnungen sind 1.539 bezahlt und 511 offen; 428 offene Rechnungen sind
zum festen Stichtag bereits überfällig.

Die Verteilungen zeigen allerdings deutliche künstliche Zusammenhänge:

- Jeder Kunde hat genau eine Kurs- und eine Ausflugsbuchung. Kunden ohne
  Buchungsdatensätze und häufig wiederkehrende Kunden fehlen.
- Genau jeder zehnte Kunde storniert beide Buchungen. Alle 125 Kurse haben
  entweder sieben bestätigte Teilnehmer (100 Kurse) oder acht (25 Kurse).
  Gering ausgelastete und leere Kurse fehlen.
- Alle 250 Mieten betreffen ausschließlich **Flossen** und nur **fünf** Artikel.
  Die 100 Buchungszuweisungen betreffen nur vier Atemregler und vier Neoprenanzüge.
  BCDs werden zwar gewartet, aber nie vermietet oder Buchungen zugewiesen.
- Sämtliche 400 Kurs- und Ausflugsrechnungen der Kunden mit einer Miete sind
  unbezahlt. Ursache ist die gemeinsame Verwendung von `n % 4` für Mietauswahl
  und Zahlungsstatus. Ein solcher Zusammenhang wurde fachlich nicht modelliert.
- Es gibt 32 Vor- und 32 Nachnamen, daraus 1.000 verschiedene Namenskombinationen.
  E-Mail-Adressen sind fortlaufend nummeriert; Telefonnummern fehlen vollständig.
  Alle Geburtsdaten liegen zwischen 08.01.1960 und 10.01.2001.
- Ausrüstungstyp, Modell und Größe hängen an derselben Viererfolge. Es gibt nur
  einen Hersteller. Lehrer sind ausnahmslos aktiv und besitzen beide Zertifikate.
- Die Kurse reichen von 05.01.2026 bis 16.03.2027. Zwei Gruppen pro Woche und
  feste Wochentage bilden weder Saisonspitzen noch unregelmäßige Nachfrage ab.

Diese Muster begrenzen die Aussagekraft von Analysen nach Kundengruppen,
Ausrüstungstypen oder Zahlungsverhalten. Die Beziehungen sind komplex, die
statistischen Verteilungen dagegen einfach und teilweise unbeabsichtigt gekoppelt.

## 2. Korrektheit der Daten

Bei der erneuten Prüfung waren alle Mengenprüfungen und alle neun fachlichen
Prüfungen erfolgreich. Die fachlichen Prüfungen betreffen:

1. Genau eine Kurs- und eine Tripbuchung pro Kunde.
2. Passenden Rechnungskunden, passenden Betrag und nicht stornierte Leistung.
3. Gültiges erforderliches Zertifikat zum Veranstaltungsbeginn.
4. Zeitfolge von Registrierung, Buchung, Veranstaltung und Abschluss.
5. Plausible Ausstellungs- und Zahlungsdaten relativ zum Stichtag.
6. Passende Ausrüstungszuweisung zu bestätigter Buchung und Veranstaltungszeit.
7. Keine Ausrüstungsbelegung nach Ausmusterung.
8. Genau einen passenden Detaileintrag je Ausrüstungsbelegung.
9. Zum Stichtag passenden Belegungsstatus.

Das belegt Konsistenz innerhalb dieser Regeln und des aktiven Schemas.
Es belegt keine vollständige fachliche Richtigkeit. Beispielsweise wird für
Kunden mit `passed_at IS NULL` nicht zwischen einem nicht bestandenen, nicht
abgelegten und noch zukünftigen Kurs unterschieden. Auch realistische
Verteilungen werden durch die Korrektheitsprüfungen nicht kontrolliert.

## 3. Edge Cases

| Fall | Im Massendatensatz vorhanden? | Aussage |
| --- | --- | --- |
| Stornierte Buchungen | Ja, 200 | Gültiger Stornozustand vorhanden; kein nachträglicher Stornovorgang getestet. |
| Bestätigte Buchung bei voller Kapazität | Ja, 25 volle Kurse und 25 volle Trips | Grenze wird erreicht; Überbuchungsversuch fehlt. |
| Offene und überfällige Rechnungen | Ja, 511 offen, davon 428 überfällig | Verschiedene Zahlungszustände vorhanden. |
| Defekte und ausgemusterte Ausrüstung | Ja, 20 Artikel | Wird nicht verplant; Ablehnung einer unzulässigen Belegung nicht getestet. |
| Vergangene und geplante Veranstaltungen | Ja | Beide Zustände vorhanden. |
| Abgelaufenes oder am Starttag ablaufendes Zertifikat | Nein | Alle `expires_at`-Werte sind NULL. |
| Stornierte Veranstaltung oder Belegung | Nein | Entsprechende Enum-Zustände fehlen. |
| Überlappende Lehrer-/Ausrüstungsplanung | Nicht als absichtlicher Fehlerfall | Generator vermeidet Konflikte. |
| Zeitintervalle mit Ende = nächstem Start | Nicht gezielt | Keine gezielte Grenzfallprüfung. |
| Fehlende Fremdschlüssel, doppelte E-Mails, negative Preise | Nicht als absichtliche Fehlerfälle | Ablehnungsverhalten im Massendatenlauf nicht nachgewiesen. |
| Preis 0 / sehr große Beträge | Nein | Rechnungsbeträge liegen zwischen 12 und 349. |
| Gleichzeitige Buchungen auf den letzten Platz | Nein | Kein Nebenläufigkeitstest. |
| Nachträgliche Änderungen und Löschungen | Nein | Massendatengenerator verwendet Inserts. |

Der wiederholte Import desselben Namensraums wurde im ersten Versuch erfolgreich
abgewehrt. Das ist eine Prüfung des Generatorschutzes und keine vollständige
Prüfung aller Datenbank-UNIQUE-Regeln.

## 4. Werden Constraints gecheckt?

**Ja, beim Einfügen.** In der lokalen Datenbank wurden für die 16 Fachtabellen
folgende Mechanismen festgestellt:

| Mechanismus | Anzahl |
| --- | ---: |
| Primärschlüssel | 16 |
| Fremdschlüssel | 22 |
| CHECK-Constraints | 22 |
| UNIQUE-Indizes ohne Primärschlüsselindizes | 20 |
| Davon partielle UNIQUE-Indizes | 2 |
| Exclusion-Constraints | 5 |
| Benutzerdefinierte Trigger | 8 |

Keiner der acht Trigger ist deaktiviert. Vier sind verzögerbare Constraint-Trigger.
Der Generator führt `SET CONSTRAINTS ALL IMMEDIATE` vor dem Commit aus, sodass
auch die verzögerten Zuordnungsprüfungen bestanden werden müssen.

**Nicht vollständig belegt ist, ob jede ungültige Eingabe korrekt abgelehnt wird.**
Der erfolgreiche Import besteht hauptsächlich aus Positivfällen.
`prisma/tests.sql` enthält separat 26 erwartete Fehlerfälle und 11 erwartete
Erfolgsfälle für den kleinen `seed.sql`-Datensatz. Sie wurden im Rahmen dieser
Analyse nicht ausgeführt und zählen nicht als getestete Abdeckung von `ai-v1`.
Die Fehlerfall-Hilfsfunktion akzeptiert zudem jeden auftretenden Fehler, ohne den
erwarteten SQLSTATE oder Constraint-Namen zu verlangen; dadurch sind falsche
positive Testergebnisse grundsätzlich möglich.

RLS ist auf allen 16 Tabellen aktiviert. Import und Analyse laufen jedoch als
`postgres`; der Zugriff als `anon` oder `authenticated` wird damit nicht getestet.

## 5. Anzahl

Der Datensatz umfasst 7.721 Zeilen: 1.000 Kunden, 10 Lehrer, 2 Zertifizierungstypen,
1.363 Kundenzertifikate, 20 Lehrerzertifikate, je 3 Kurse und Tauchplätze, je
125 Kurstermine und Ausflüge, 2.000 Buchungen, 120 Ausrüstungsartikel,
450 Belegungen mit insgesamt 450 passenden Detailzeilen und 2.050 Rechnungen.

Die Größe passt zum angefragten ersten Versuch. Ein Test von Indexselektivität,
großen Joins, Importskalierung oder hoher gleichzeitiger Last ist damit noch
nicht durchgeführt. Die Obergrenze von 100.000 Kunden ist lediglich im Generator
erlaubt; sie wurde nicht ausprobiert. Lehrer und Ausrüstung bleiben dabei konstant,
und zusätzliche Kunden verlängern den Kalender statt die gleichzeitige Auslastung.

## 6. Aufwand der Erstellung

Vorhanden sind 214 Zeilen Generatorskript, 157 Zeilen Prüfskript und 25 Zeilen
Shell-Anbindung, jeweils einschließlich Kommentaren und Leerzeilen. Der
Erstellungsumfang umfasst Schemaanalyse, Berücksichtigung der SQL-Trigger,
Datengenerierung, lokale Einrichtung und Verifikation.

Es gibt keine getrennte, belastbare Zeitmessung dieser Schritte. Deshalb lässt
sich weder eine konkrete Zeitersparnis noch ein Vorteil gegenüber dem Library-
Ansatz behaupten. Nach der Einrichtung ist die Bedienung gering aufwendig:
ein Importbefehl und ein wiederholbarer Prüfbefehl. Für eine vergleichbare
Aufwandsmessung müssen auch Review und notwendige Korrekturen erfasst werden.

## 7. Aufwand der Schemaänderung

Diese Einschätzung beruht auf dem Code; ein praktischer Schemaänderungsversuch
wurde nicht durchgeführt.

| Änderung | Erwarteter Anpassungsbedarf |
| --- | --- |
| Neue optionale Spalte oder Spalte mit passendem Default | Vorhandene Inserts können weiter funktionieren; für aussagekräftige Daten muss die neue Spalte dennoch befüllt und geprüft werden. |
| Neue Pflichtspalte ohne Default | Betroffene Inserts im Generator anpassen. |
| Umbenannte Spalte, anderer Datentyp oder Enum | Migration, Generator und betroffene Prüfqueries anpassen. |
| Neue Beziehung oder Tabelle | Erzeugungsreihenfolge, ID-Zuordnung, Mengen- und Fachprüfungen erweitern. |
| Neue Geschäftsregel oder Trigger | Regeln im Generator und Prüfer anpassen; gegebenenfalls Zeitplan und Zertifikatslogik neu gestalten. |

Explizite Spaltenlisten und automatisch vergebene IDs erleichtern Änderungen.
Eine automatische Anpassung an ein geändertes Prisma-Schema gibt es jedoch nicht.
Die KI benötigt erneut das aktuelle Schema **und** die SQL-Migrationen. Der
Prüfer enthält eigene Mengenannahmen und muss bei Verteilungsänderungen mitgeändert
werden. Erwartet wird daher mittlerer, bei komplexen Regeländerungen höherer Aufwand.

## 8. Coverage

| Dimension | Gemessene oder festgestellte Abdeckung |
| --- | --- |
| Tabellen | 16/16 Tabellen enthalten Daten. |
| Spalten mit mindestens einem Nicht-NULL-Wert | 104/107 Spalten. |
| Ausschließlich NULL | `customers.phone`, `customer_certifications.expires_at`, `instructor_certifications.expires_at`. |
| Enum-Werte | 13/15 verschiedene deklarierte Enum-Werte kommen vor. |
| Fehlende Enum-Werte | `ScheduleStatus.cancelled`, `AllocationStatus.cancelled`. |
| Buchungstypen | Kurs und Ausflug vorhanden. |
| Belegungstypen | Miete, Zuweisung und Wartung vorhanden; Ausrüstungstypen je Verwendung stark eingeschränkt. |
| Fachliche Zusatzprüfungen | Neun Prüfkategorien ohne Abweichungen. |
| Fehler-, Änderungs-, Lösch- und Nebenläufigkeitsfälle | Im Massendatenlauf nicht systematisch getestet. |
| Zugriffsrechte / RLS-Policies | Nicht durch den Lauf als `postgres` getestet. |

Die Werte 16/16 und 104/107 beschreiben Datenbelegung, **keine vollständige
Testabdeckung**. Auch 13/15 Enum-Werte sagen nichts darüber aus, ob relevante
Zustandsübergänge oder Kombinationen getestet wurden.

## Konsequenzen für die weitere Arbeit

1. **Unbeabsichtigte Korrelationen entfernen:** Mietauswahl, Ausrüstungstyp,
   Zahlungsstatus und Storno voneinander unabhängig steuern. Unterschiedliche
   Buchungshäufigkeiten und Auslastungen ergänzen.
2. **Gezielte Grenz- und Fehlerfälle ergänzen:** Zertifikatsablauf, Überbuchung,
   Zeitgrenzen, Überschneidungen und ungültige Zuordnungen. Erwartete Fehler anhand
   von SQLSTATE oder Constraint-Namen prüfen und jeden Versuch zurückrollen.
3. **Vergleich messbar machen:** Für KI- und Library-Ansatz dieselbe Zielgröße,
   Verteilungen und Prüfkriterien verwenden; Erstellungs-/Korrekturaufwand,
   Schemaänderung und Importdauer getrennt messen.

Die aktuelle Version eignet sich gut als reproduzierbarer erster Import- und
Integritätsdatensatz. Für realistische Lastuntersuchungen und umfassende
Constraint-Tests sind zusätzliche Verteilungen und gezielte Testszenarien nötig.
