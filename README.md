# TauchDB
Verwaltung einer Tauchschule
# Anforderungsdefinition – DiveManager
**Projekt:** Digitales Verwaltungssystem für eine Tauchschule  
**Modul:** Advanced Databases  
**Zieldatenbank:** PostgreSQL  
**Projektumfang:** 15 relationale Tabellen  
**Version:** 1.0 – Anforderungsanalyse

---

## 1. Projektbeschreibung

DiveManager ist ein datenbankgestütztes Verwaltungssystem für Tauchschulen.

Ziel ist es, die organisatorischen und administrativen Abläufe einer Tauchschule zentral abzubilden. Dazu gehören Kundenverwaltung, Kursorganisation, Zertifizierungen, Tauchausflüge, Ausrüstungsverleih, Wartungen und Abrechnungen.

Das System soll redundante Datenspeicherung vermeiden, Datenkonsistenz sicherstellen und typische Geschäftsprozesse einer Tauchschule unterstützen.

Im Rahmen des Hochschulprojekts steht die **Konzeption und Implementierung einer relationalen Datenbank mit 15 Tabellen** im Vordergrund. Eine vollständige Benutzeroberfläche ist zunächst nicht Bestandteil des verpflichtenden Projektumfangs.

## 2. Funktionale Anforderungen

### FA-01: Kundenverwaltung

Das System muss:
- Kunden mit eindeutiger ID registrieren können.
- Namen, Kontaktdaten und Registrierungsdatum speichern.
- Bestehende Kundendaten ändern können.
- Kunden anhand ihrer ID suchen können.
- Die Buchungs- und Zertifizierungshistorie eines Kunden anzeigen können.

**Geschäftsregel:** Jede Kursbuchung, Ausflugsanmeldung und Ausrüstungsvermietung muss einem Kunden zugeordnet sein.

### FA-02: Verwaltung von Tauchlehrern

Das System muss:
- Tauchlehrer mit eindeutiger ID verwalten.
- Namen, Kontaktdaten und Qualifikationsinformationen speichern.
- Tauchlehrer zu Kursterminen und Tauchausflügen zuordnen können.
- Die geplanten Einsätze eines Tauchlehrers abrufen können.

**Geschäftsregel:** Ein Tauchlehrer darf nicht gleichzeitig für zwei zeitlich überlappende Veranstaltungen eingeteilt werden. Die Einteilung erfolgt in der ersten Version durch einen verantwortlichen Mitarbeiter.

### FA-03: Kursmanagement

Das System muss:
- Unterschiedliche Kursarten verwalten.
- Kursbezeichnungen, Beschreibungen und Preise speichern.
- Voraussetzungen für die Kursteilnahme definieren können.
- Konkrete Kurstermine mit Anfang, Ende, maximaler Teilnehmerzahl und Tauchlehrer verwalten.
- Kursanmeldungen ermöglichen.
- Anmeldungen stornieren können.
- Erfolgreich abgeschlossene Kurse dokumentieren können.

**Geschäftsregeln:**
- Die maximale Teilnehmerzahl darf nicht überschritten werden.
- Ein Kunde darf denselben Kurstermin nicht mehrfach aktiv buchen.
- Ein Kurs darf nur gebucht werden, wenn die erforderliche Zertifizierung vorliegt.
- Die Kapazitätsprüfung muss auch bei gleichzeitigen Buchungsversuchen zuverlässig funktionieren.

### FA-04: Zertifizierungsverwaltung

Das System muss:
- Unterschiedliche Zertifikatstypen verwalten.
- Zertifikate einzelnen Kunden zuordnen.
- Ausstellungsdatum, Zertifikatsnummer und gegebenenfalls Gültigkeitsdatum speichern.
- Kursvoraussetzungen anhand vorhandener Zertifikate überprüfen.
- Zertifikate eines Kunden abrufen können.

**Geschäftsregel:** Zertifikate müssen eindeutig zuordenbar sein. Abgelaufene Zertifikate dürfen nicht als gültige Voraussetzungen verwendet werden, sofern die jeweilige Zertifizierung eine Gültigkeitsfrist besitzt.

### FA-05: Verwaltung von Tauchplätzen und Tauchausflügen

Das System muss:
- Tauchplätze mit Namen, Standort und maximal vorgesehener Tiefe verwalten.
- Tauchausflüge mit Datum, Uhrzeit, Tauchplatz und Teilnehmerlimit anlegen.
- Einen verantwortlichen Tauchlehrer beziehungsweise Guide zuweisen.
- Kunden zu Tauchausflügen anmelden.
- Teilnehmerlisten erstellen.
- Ausflüge absagen und Buchungen stornieren können.

**Geschäftsregeln:**
- Die Teilnehmerkapazität darf nicht überschritten werden.
- Ein Kunde darf nicht mehrfach aktiv für denselben Ausflug angemeldet sein.
- Für Ausflüge kann eine Mindestzertifizierung hinterlegt werden.
- Der verantwortliche Tauchlehrer darf keine zeitlichen Überschneidungen haben.

### FA-06: Ausrüstungsverwaltung

Das System muss:
- Ausrüstungsgegenstände mit eindeutiger Inventarnummer speichern.
- Gerätetyp, Hersteller, Modell und Zustand dokumentieren.
- Verleihvorgänge einem Kunden und einem Zeitraum zuordnen.
- Rückgaben erfassen.
- Wartungen und Reparaturen dokumentieren.
- Die aktuelle Verfügbarkeit eines Ausrüstungsgegenstandes ermitteln.

**Geschäftsregeln:**
- Ein Gegenstand darf nicht in überlappenden Zeiträumen mehrfach verliehen werden.
- Defekte oder gesperrte Gegenstände dürfen nicht verliehen werden.
- Während einer Wartung ist der Gegenstand nicht verleihbar.
- Jeder Verleihvorgang benötigt ein Startdatum und ein geplantes Rückgabedatum.

### FA-07: Rechnungs- und Zahlungsverwaltung

Das System muss:
- Rechnungen für Kursbuchungen, Ausflugsanmeldungen und Ausrüstungsvermietungen erfassen.
- Rechnungen einem Kunden zuordnen.
- Rechnungsnummer, Betrag, Rechnungsdatum und Fälligkeit speichern.
- Eine oder mehrere Zahlungen pro Rechnung dokumentieren.
- Offene und vollständig bezahlte Rechnungen ermitteln.

**Geschäftsregeln:**
- Jede Rechnung besitzt eine eindeutige Rechnungsnummer.
- Zahlungsbeträge müssen positiv sein.
- Zahlungen dürfen nicht ohne gültige Rechnung existieren.
- Eine Rechnung bezieht sich in Version 1 genau auf eine kostenpflichtige Leistung. Sammelrechnungen mit mehreren Positionen sind vorerst ausgeschlossen.

### FA-08: Auswertungen

Die Datenbank soll folgende Auswertungen ermöglichen:
- Anzahl aktiver Kunden
- Gebuchte und verfügbare Kursplätze
- Umsatz pro Monat
- Offene Rechnungen
- Anstehende Wartungen
- Auslastung der Tauchlehrer
- Beliebteste Kurse
- Verfügbare Ausrüstungsgegenstände

Die Auswertungen sollen über SQL-Abfragen beziehungsweise Views realisiert werden.

---

## 3. Datenmodell – 15 Tabellen

| Nr. | Tabelle | Inhalt |
|---|---|---|
| 1 | customers | Kundenstammdaten |
| 2 | instructors | Tauchlehrer |
| 3 | courses | Kursarten und Voraussetzungen |
| 4 | course_sessions | Einzelne Kurstermine |
| 5 | course_bookings | Anmeldungen zu Kursterminen |
| 6 | certifications | Verfügbare Zertifizierungstypen |
| 7 | customer_certifications | Erteilte Zertifikate |
| 8 | dive_sites | Tauchplätze |
| 9 | dive_trips | Organisierte Tauchausflüge |
| 10 | trip_participants | Ausflugsanmeldungen |
| 11 | equipment | Ausrüstungsinventar |
| 12 | equipment_rentals | Ausrüstungsvermietungen |
| 13 | equipment_maintenance | Wartungen und Reparaturen |
| 14 | invoices | Rechnungen |
| 15 | payments | Zahlungsvorgänge |

### Wichtige Beziehungen

- Ein Kunde kann mehrere Kursbuchungen besitzen (1:n).
- Ein Kurstermin kann mehrere Kursbuchungen besitzen (1:n).
- Ein Tauchlehrer kann mehrere Kurstermine betreuen (1:n).
- Ein Kunde kann mehrere Zertifizierungen besitzen (n:m über customer_certifications).
- Ein Tauchplatz kann mehreren Tauchausflügen zugeordnet sein (1:n).
- Ein Tauchausflug kann mehrere Teilnehmer besitzen (n:m über trip_participants).
- Ein Ausrüstungsgegenstand kann mehrfach vermietet werden (1:n).
- Ein Ausrüstungsgegenstand kann mehrere Wartungseinträge besitzen (1:n).
- Ein Kunde kann mehrere Rechnungen besitzen (1:n).
- Eine Rechnung kann mehrere Zahlungen besitzen (1:n).

Die Teilnahmevoraussetzungen eines Kurses werden in Version 1 über eine optionale erforderliche Zertifizierung in der Tabelle `courses` modelliert. Umfangreichere Abhängigkeiten zwischen mehreren Zertifikaten wären eine spätere Erweiterung.

## 4. Nichtfunktionale Anforderungen

**NFA-01 – Datenintegrität:** Primärschlüssel, Fremdschlüssel, UNIQUE-Constraints und CHECK-Constraints sichern die Konsistenz.

**NFA-02 – Normalisierung:** Das Datenmodell soll mindestens die dritte Normalform (3NF) erfüllen, soweit fachlich sinnvoll.

**NFA-03 – Transaktionssicherheit:** Kritische Prozesse, insbesondere Buchungen und Verleihvorgänge, müssen atomar und konkurrenzsicher ausgeführt werden.

**NFA-04 – Performance:** Häufige Such- und Verknüpfungsoperationen sollen durch geeignete Indizes unterstützt werden.

**NFA-05 – Erweiterbarkeit:** Die Datenbank soll eine spätere Erweiterung um Webanwendung, Kundenportal und mehrere Tauchschulen erlauben.

**NFA-06 – Datenschutz:** Personenbezogene Daten sollen nur im erforderlichen Umfang gespeichert werden. Für den Prototyp werden ausschließlich fiktive Testdaten verwendet.

**NFA-07 – Nachvollziehbarkeit:** Das SQL-Schema und die Datenbankobjekte müssen versioniert und anhand von Skripten reproduzierbar sein.

## 5. Advanced-Database-Anforderungen

Folgende technische Funktionen sollen umgesetzt beziehungsweise demonstriert werden:

1. **Stored Function oder Procedure:** Transaktionssichere Buchung eines Kurses inklusive Kapazitätskontrolle.
2. **Trigger:** Sicherstellung zusätzlicher Konsistenzregeln beim Ändern von Datensätzen.
3. **Views:** Kursauslastung und offene Rechnungen.
4. **Komplexe SQL-Abfragen:** Umsatzstatistiken, Rangfolgen und Auslastungsanalysen mittels JOIN, GROUP BY und gegebenenfalls Window Functions.
5. **Indizes:** Optimierung häufig ausgeführter Abfragen.
6. **Transaktionen:** Korrekte Behandlung gleichzeitiger Buchungen und sich überschneidender Verleihvorgänge.
7. **Constraints:** Absicherung fachlicher Regeln direkt auf Datenbankebene.

## 6. Abgrenzung des Projektumfangs

**Für das Uni-Projekt vorgesehen:**
- 15 normalisierte Tabellen
- Vollständiges ER-Diagramm
- PostgreSQL-Schema
- Primär- und Fremdschlüssel
- Definierte Geschäftsregeln
- Realistische Testdaten
- Beispielabfragen
- Ausgewählte fortgeschrittene Datenbankfunktionen
- Dokumentation und Präsentation

**Zunächst nicht vorgesehen:**
- Vollständige Webanwendung
- Online-Zahlungsanbieter
- Mobile App
- Automatische Ausstellung offizieller Verbandszertifikate
- Live-Wetterdaten oder externe Schnittstellen
- Mandantenfähige Verwaltung mehrerer Tauchschulen
- Produktivbetrieb mit echten Kundendaten

Diese Funktionen können später für eine kommerzielle Version ergänzt werden.

## 7. Akzeptanzkriterien

Das Projekt gilt aus Datenbanksicht als erfolgreich umgesetzt, wenn:

- Alle 15 Tabellen erstellt und mit Beziehungen verbunden sind.
- Das ER-Diagramm mit dem implementierten Schema übereinstimmt.
- Beispieldaten importiert werden können.
- Kunden und Kurse angelegt werden können.
- Kursbuchungen mit gültigen Voraussetzungen funktionieren.
- Überbuchungen bei gleichzeitigen Buchungsversuchen verhindert werden.
- Ausrüstungsverleih ohne zeitliche Doppelbelegung möglich ist.
- Wartungszeiten beim Verleih berücksichtigt werden.
- Rechnungen und zugehörige Zahlungen gespeichert werden.
- Mindestens zwei aussagekräftige Views und mehrere komplexe SQL-Abfragen funktionieren.
- SQL-Skripte die Datenbank reproduzierbar erstellen können.
- Kritische Geschäftsregeln durch Positiv- und Negativtests überprüft wurden.

## 8. Aufgabenverteilung bei drei Teammitgliedern

**Person 1 – Kunden- und Kursmanagement**
- Tabellen 1–5
- Kursverwaltung und Buchungslogik
- Kapazitätskontrolle
- Dokumentation des eigenen Bereichs

**Person 2 – Zertifizierungen und Tauchausflüge**
- Tabellen 6–10
- Zertifizierungsvoraussetzungen
- Verwaltung der Ausflüge
- ER-Modellierung der Zusammenhänge
- Dokumentation des eigenen Bereichs

**Person 3 – Ausrüstung und Finanzen**
- Tabellen 11–15
- Ausrüstungsverleih
- Wartungsverwaltung
- Rechnungen und Zahlungen
- Dokumentation des eigenen Bereichs

**Gemeinsame Aufgaben:**
- Abstimmung von Fremdschlüsseln und Schnittstellen
- Zusammenführung des ER-Diagramms
- Integration der SQL-Skripte
- Datenbanktests
- Finale Dokumentation und Pitch

Die Zuordnung der Personen erfolgt nach Absprache im Team.

## 9. Nächster Meilenstein

Für das nächste Meeting sollen folgende Ergebnisse vorliegen:

1. Zieldatenbank PostgreSQL ausgewählt und begründet.
2. 15 Tabellen einschließlich wesentlicher Attribute definiert.
3. Primär- und Fremdschlüssel festgelegt.
4. Vollständiges ER-Diagramm erstellt.
5. Datenmodell nach Möglichkeit in PostgreSQL umgesetzt.
6. Dokumentation von ungefähr fünf Seiten vorbereitet, mit erkennbaren Verantwortlichkeiten.
7. Pro Person ein kurzer Status-Pitch (maximal fünf Minuten) mit erreichten und nicht erreichten Zielen vorbereitet.

**Projektziel:** Eine konsistente, erweiterbare und fachlich nachvollziehbare Datenbank als Grundlage einer digitalen Tauchschulverwaltung entwickeln.
