# SSH-Manager

[Read in English](./README.md)

Mit SSH-Manager speicherst du deine SSH-Ziele in einem Terminalmenü. Das Tool läuft in PowerShell oder in Bash unter Linux. Gib eine Zielnummer ein, um eine SSH-Sitzung mit dem gespeicherten Host, Benutzernamen und Port zu öffnen.

## SSH-Manager installieren

### Linux

Du brauchst Bash ab 4.4, Git, `jq` ab 1.6, `curl`, den OpenSSH-Client und `flock` aus util-linux. Unter Debian und Ubuntu kannst du fehlende Pakete mit `sudo apt install git jq curl openssh-client util-linux` installieren.

```bash
curl -fsSL https://raw.githubusercontent.com/eb-88/SSH-Manager/main/install.sh | bash
```

Für spätere Starts kannst du `~/.local/bin/ssh-manager` verwenden. Wenn `~/.local/bin` in deinem `PATH` steht, funktionieren `ssh-manager`, `sshm` und `SSHM` gleichwertig. Nach einem Update über die integrierte Updatefunktion legt das aktualisierte Linux-Skript beim nächsten Start fehlende Kurzbefehle automatisch an, ohne bestehende fremde Befehle zu überschreiben.

Beim erneuten Ausführen des Installationsbefehls wird eine vorhandene Installation erkannt. Ein Update erfolgt nur nach Bestätigung (`y` oder `j`); bei Ablehnung bleiben die vorhandenen Dateien unverändert.

### PowerShell

Du brauchst Windows PowerShell 5.1 oder PowerShell 7, Git und die OpenSSH-Befehle `ssh` und `ssh-keygen`.

```powershell
irm https://raw.githubusercontent.com/eb-88/SSH-Manager/main/install.ps1 | iex
```

Auch unter PowerShell fragt der Installationsbefehl bei einer vorhandenen Installation vor einem Update nach.

Bestätige beim ersten Start mit **y** (oder **j**), damit du `SSH-Manager` aus jedem Ordner aufrufen kannst. Zusätzlich stehen `SSHM` und `sshm` als Kurzaufrufe zur Verfügung (PowerShell unterscheidet nicht zwischen Groß- und Kleinschreibung). Bestehende Module werden beim nächsten Start des aktualisierten Skripts ergänzt. `sshm` funktioniert anschließend direkt in derselben PowerShell-Sitzung; ein Neustart des Terminals ist nicht nötig. Lass den Installationsordner an seinem Platz, damit die Befehle das Skript finden.

## Sprache im Terminal

SSH-Manager startet standardmäßig mit englischen Menüs, unabhängig von der Systemsprache. Unter **O → G → 1** wählst du Englisch und unter **O → G → 2** Deutsch. Die Auswahl wird in `~/.ssh/ssh-manager/language` gespeichert und gilt für beide Skripte auf demselben Gerät.

Für einen einzelnen Start kannst du die gespeicherte Auswahl mit `SSH_MANAGER_LANG=de` oder `SSH_MANAGER_LANG=en` überschreiben. In PowerShell setzt du beispielsweise `$env:SSH_MANAGER_LANG = 'de'`. SSH-Zieldaten, Anmeldearten und das JSON-Import-/Exportformat bleiben unverändert.

## Die erste Verbindung

1. Öffne mit **O** das Menü `Optionen` und wähle **N** für `Neu`. Vergib einen Kurznamen wie `build-box` und trage den Hostnamen oder die IP-Adresse sowie deinen SSH-Benutzernamen ein. Übernimm Port **22** mit **Enter** oder gib einen anderen Port an.
2. Wähle unter `Anmeldung` die **1**, um mit deinem Serverpasswort einen Schlüssel einzurichten. Mit **2** verwendest du deine bestehende OpenSSH-Konfiguration, einschließlich eines gegebenenfalls erforderlichen zweiten Faktors.
3. Gib die Zielnummer aus der Übersicht ein. Gleiche beim ersten Kontakt den angezeigten Host-Fingerabdruck mit der Serveradministration ab, bevor du ihn bestätigst. Mit `exit` beendest du die SSH-Sitzung und kehrst zum Menü zurück.

Bei **Option 1** prüft der Manager zuerst die Passwortanmeldung und erzeugt danach lokal ein Ed25519-Schlüsselpaar. OpenSSH fragt nach einer Passphrase zum Schutz des privaten Schlüssels. Gib dein **Serverpasswort ein zweites Mal** ein, damit der Manager den öffentlichen Schlüssel auf dem Server in `~/.ssh/authorized_keys` eintragen kann. Die Einrichtung ist abgeschlossen, sobald der Server die Anmeldung mit genau diesem Schlüssel bestätigt hat. Schlägt die Prüfung fehl, verbinde dich erneut, um denselben Schlüssel zu verwenden. Kann der Manager den Schlüssel weiterhin nicht bestätigen, fragt er vor einer erneuten Freigabe nach, da ein neuer Eintrag bestehende Beschränkungen umgehen kann. Die Einrichtung setzt ein Linux- oder Unix-Konto mit kompatibler Shell und Schreibzugriff auf diese Datei voraus.

## Gespeicherte Ziele verwalten

Die Übersicht zeigt Kurzname, Verbindung und Anmeldeart. In einem schmalen Terminal stehen die Angaben untereinander. Gib eine Zielnummer ein, um direkt zu verbinden, oder **Q**, um den Manager zu beenden.

Mit **O** öffnest du das Menü `Optionen`. **Enter** bringt dich von dort zurück zur Übersicht. Beim Anlegen und Bearbeiten übernimmt **Enter** den Wert in eckigen Klammern. Mit **!** brichst du ab. Fehlerhafte Eingaben kannst du direkt im jeweiligen Feld korrigieren.

| Eingabe | Menüpunkt | Aktion |
| --- | --- | --- |
| **N** | Neu | Ein Ziel hinzufügen. |
| **A** | Automatische Updates | Automatische Updateprüfung beim Start ein- oder ausschalten (standardmäßig ein). |
| **U** | Nach Updates suchen | Manuell nach einem GitHub-Release suchen und ein angebotenes Update installieren. |
| **S** | Suchen | Live-Volltextsuche über Kurzname, Host, Benutzer, Port und Anmeldeart. Die Treffer aktualisieren sich bei jedem Tastendruck; mehrere Wörter können unterschiedliche Felder treffen. **Enter** übernimmt den Filter, **Esc** bricht ab und **Backspace** löscht Zeichen. Ein leerer Suchbegriff mit Enter zeigt wieder alle Ziele. Ohne interaktives Terminal bleibt die normale Zeileneingabe erhalten. |
| **B** | Bearbeiten | Ein Ziel zum Bearbeiten auswählen. Beim Umbenennen bleibt der Schlüssel zugeordnet. Änderst du nur den Port, übernimmst du mit Enter den bisherigen Schlüssel. Der Manager prüft ihn beim nächsten Verbindungsaufbau am neuen Port. Mit **n** richtest du einen anderen ein. |
| **L** | Löschen | Ein Ziel auswählen und mit **j** aus der Liste entfernen. |
| **I** | Import | Ziele aus einer exportierten JSON-Datei übernehmen. Gleichnamige Ziele werden übersprungen. |
| **E** | Export | Alle Ziele in eine neue JSON-Datei schreiben, auch bei aktiver Suche. |
| **D** | Skriptordner öffnen | Eine lokale Shell im Skriptverzeichnis öffnen. |
| **R** | Skript ausführen | Ein Skript und danach den Zielserver auswählen. |

PowerShell und Bash verwenden dasselbe JSON-Exportformat. Die Datei enthält Kurznamen, Hosts, Benutzernamen, Ports und Anmeldearten. Öffentliche und private Schlüssel, Passwörter, lokale Schlüsselzuordnungen und OpenSSH-Konfiguration bleiben auf dem ursprünglichen Gerät. Beim ersten Verbinden mit einem importierten Ziel richtet der Manager bei Bedarf einen neuen verwalteten Schlüssel ein. Ziele mit der Anmeldeart **OpenSSH** verwenden die Konfiguration des aktuellen Rechners.

Die Zielprofile liegen als `ziel-*.json` in `~/.ssh/ssh-manager/` in deinem Benutzerverzeichnis. Im selben Ordner liegen die vom Manager erzeugten Schlüssel. Serverpasswörter werden nicht gespeichert. Beim Löschen eines Ziels bleiben die lokalen Schlüsseldateien und die zugehörige Zugriffsberechtigung auf dem Server erhalten.


## Eigene Skripte ausführen

Der Manager legt beim Start zwei lokale Ordner an. Bash-Skripte in `~/.ssh/ssh-manager/scripts/user/` laufen als gespeicherter SSH-Benutzer. Skripte in `~/.ssh/ssh-manager/scripts/root/` laufen als Root. Dafür muss der SSH-Benutzer auf dem Ziel `sudo -u root -- bash` ausführen dürfen oder bereits als Root angemeldet sein.

1. Öffne mit **O → D** das Skriptverzeichnis. Lege dort zum Beispiel mit `nano user/status.sh` ein Skript mit der Zeile `uptime` an. Speichere es und kehre mit `exit` zum Manager zurück.
2. Wähle **O → R**, die Skriptnummer und anschließend die Zielnummer. Die Liste zeigt den Ordner bei jedem Dateinamen an. **Enter** bricht die Auswahl ab.

Auf dem Ziel muss Bash installiert sein. Die lokalen `.sh`-Dateien brauchen kein Ausführungsbit. Der Manager überträgt das gewählte Skript in eine temporäre Datei und startet es in einer zweiten SSH-Verbindung. Dabei sind Eingaben für `sudo` und für das Skript direkt im Terminal möglich. Nach der Ausführung wird die temporäre Datei entfernt.

## Updates

Das Hauptmenü zeigt stets die installierte Skriptversion an. Wenn du eine neuere Version ablehnst oder das Update fehlschlägt, erscheint im Menü ein Hinweis **Veraltete Version** mit der verfügbaren Version. Ein erfolgreiches Update wird beim nächsten Start aktiv.


Automatische Updateprüfungen sind **standardmäßig aktiviert**. Unter **O → A** kannst du sie dauerhaft deaktivieren oder wieder aktivieren. Über **O → U** kannst du jederzeit manuell nach einem neuen GitHub-Release suchen und die Installation bestätigen – auch wenn die automatische Prüfung deaktiviert ist. Die Einstellung wird unter `~/.ssh/ssh-manager/auto-update` gespeichert und von PowerShell und Bash im selben Benutzerverzeichnis gemeinsam verwendet. Updates sind beim nächsten Start aktiv; SSH-Ziele und Schlüssel bleiben erhalten. Das Skriptverzeichnis muss beschreibbar sein; Bash verwendet `curl` und GNU `sort`.
