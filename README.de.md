# SSH-Manager

[Read in English](./README.md)

Mit SSH-Manager speicherst du deine SSH-Ziele in einem Terminalmenü. Das Tool läuft in PowerShell oder in Bash unter Linux. Gib eine Zielnummer ein, um eine SSH-Sitzung mit dem gespeicherten Host, Benutzernamen und Port zu öffnen.

## Erster Start

### PowerShell

Du brauchst Windows PowerShell 5.1 oder PowerShell 7 sowie die OpenSSH-Befehle `ssh` und `ssh-keygen`. Mit `Get-Command ssh, ssh-keygen` prüfst du, ob PowerShell beide findet.

Öffne in Azure DevOps **Repos → Files → Clone** und kopiere die Klon-URL. Ersetze den Platzhalter im folgenden Beispiel durch diese URL und führe die Befehle in PowerShell aus.

```powershell
git clone "<Klon-URL>" SSH-Manager
Set-Location SSH-Manager
.\SSH-Manager.ps1
```

Ist der globale Befehl verfügbar, öffnet sich direkt das Menü. Andernfalls bietet das Skript an, ihn für dein Benutzerkonto einzurichten. Mit **j** stimmst du zu. Danach kannst du `SSH-Manager` aus jedem Ordner aufrufen, auch in einer neuen PowerShell-Sitzung. Lass das Skript an seinem Speicherort, weil der Befehl auf diese Datei verweist. Mit **Enter** überspringst du die Einrichtung und gelangst ins Menü.

### Linux

Die Linux-Version benötigt Bash ab 4.4, `jq` ab 1.6, den OpenSSH-Client und `flock` aus util-linux. Unter Debian und Ubuntu kannst du die Befehle mit `sudo apt install jq openssh-client util-linux` installieren.

Starte das Menü aus dem geklonten Repository.

```bash
bash ./ssh-manager.sh
```

Wenn `~/.local/bin` in deinem `PATH` steht, kannst du das Skript als Befehl `ssh-manager` installieren.

```bash
install -Dm755 ssh-manager.sh ~/.local/bin/ssh-manager
ssh-manager
```

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
| **S** | Suchen | Nach Kurzname, Host, Benutzer oder Port filtern. Lass den Suchbegriff leer, um wieder alle Ziele anzuzeigen. |
| **B** | Bearbeiten | Ein Ziel zum Bearbeiten auswählen. Beim Umbenennen bleibt der Schlüssel zugeordnet. Änderst du nur den Port, übernimmst du mit Enter den bisherigen Schlüssel. Der Manager prüft ihn beim nächsten Verbindungsaufbau am neuen Port. Mit **n** richtest du einen anderen ein. |
| **L** | Löschen | Ein Ziel auswählen und mit **j** aus der Liste entfernen. |
| **I** | Import | Ziele aus einer exportierten JSON-Datei übernehmen. Gleichnamige Ziele werden übersprungen. |
| **E** | Export | Alle Ziele in eine neue JSON-Datei schreiben, auch bei aktiver Suche. |

PowerShell und Bash verwenden dasselbe JSON-Exportformat. Die Datei enthält Kurznamen, Hosts, Benutzernamen, Ports und Anmeldearten. Öffentliche und private Schlüssel, Passwörter, lokale Schlüsselzuordnungen und OpenSSH-Konfiguration bleiben auf dem ursprünglichen Gerät. Beim ersten Verbinden mit einem importierten Ziel richtet der Manager bei Bedarf einen neuen verwalteten Schlüssel ein. Ziele mit der Anmeldeart **OpenSSH** verwenden die Konfiguration des aktuellen Rechners.

Die Zielprofile liegen als `ziel-*.json` in `~/.ssh/ssh-manager/` in deinem Benutzerverzeichnis. Im selben Ordner liegen die vom Manager erzeugten Schlüssel. Serverpasswörter werden nicht gespeichert. Beim Löschen eines Ziels bleiben die lokalen Schlüsseldateien und die zugehörige Zugriffsberechtigung auf dem Server erhalten.
