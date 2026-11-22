# SSH-Manager

[Deutsch lesen](./README.de.md)

SSH-Manager saves your SSH destinations in a terminal menu that runs in PowerShell or in Bash on Linux. Enter a target number to open an SSH session with the saved host, user and port. The terminal defaults to English, and you can switch to German in Options.

## Install SSH-Manager

### Linux

Requires Bash 4.4 or later, Git, `jq` 1.6 or later, `curl`, the OpenSSH client, and `flock` from util-linux. On Debian and Ubuntu, run `sudo apt install git jq curl openssh-client util-linux` if needed.

```bash
curl -fsSL https://raw.githubusercontent.com/eb-88/SSH-Manager/main/install.sh | bash
```

Running the installation command again detects the existing checkout and asks before updating it. If you decline, no files are changed. A failed Git pull does not overwrite existing files. To start it again, run `~/.local/bin/ssh-manager`, or just `ssh-manager` if `~/.local/bin` is on your `PATH`.

### PowerShell

Requires Windows PowerShell 5.1 or PowerShell 7, Git, and the OpenSSH commands `ssh` and `ssh-keygen`.

```powershell
irm https://raw.githubusercontent.com/eb-88/SSH-Manager/main/install.ps1 | iex
```

Running the installation command again offers an update of the existing checkout (only after confirmation). When prompted on first installation, enter **j** to register `SSH-Manager` for your account. Keep the installed folder in place so the command can find the script.

## Updates

The main menu always shows the installed script version. If you decline an offered newer release or its installation fails, the menu displays an **Outdated version** warning with the available version. A successful install takes effect on the next start.


Automatic update checks are **enabled by default**. When enabled, SSH Manager checks the latest stable GitHub release at startup and asks before installing a newer version. Under **O → A**, toggle automatic checks on or off. Under **O → U**, manually check for updates and choose whether to install one, even when automatic checks are disabled. The preference is saved in `~/.ssh/ssh-manager/auto-update` and is shared between PowerShell and Bash on the same home directory. Updates take effect on the next launch; saved SSH targets and keys remain unchanged. The script's installation directory must be writable; Bash checks use `curl` and GNU `sort`.

## Terminal language

English is the default on both PowerShell and Bash, independent of your operating-system language. Open **O → G → 1** for English or **O → G → 2** for German. The selection is saved in `~/.ssh/ssh-manager/language` and shared by both scripts on the same machine.

You can override the saved setting for a single launch with `SSH_MANAGER_LANG=en` or `SSH_MANAGER_LANG=de` (use `$env:SSH_MANAGER_LANG = 'de'` in PowerShell). The SSH profile files, login method identifiers, and import/export JSON format remain unchanged.

## Connect to your first target

1. Enter **O** to open `Options`, then **N** for `New`. Give the target a short name such as `build-box`, then enter its hostname or IP address and your SSH username. Press **Enter** to accept port **22**, or type a different port.
2. At `Login`, choose **1** to set up a key using your server password, or **2** to use your existing OpenSSH configuration, including any required second factor.
3. Enter the target’s number in the overview. On first contact, verify the host fingerprint with your server administrator before accepting it. When you finish the remote session, type `exit` to return to the menu.

With **option 1**, the manager checks your password login before generating a local Ed25519 key pair. OpenSSH prompts for a passphrase to protect the private key. Enter your **server password a second time** so the manager can add the public key to `~/.ssh/authorized_keys` on the server. The manager verifies that the server accepts this specific key before marking setup complete. If verification fails, reconnect to retry with the same key. If the key still cannot be verified, the manager asks before authorizing it again because a new entry can bypass existing restrictions. This setup requires a Linux or Unix account with a compatible shell and write access to that file.

## Manage saved targets

The overview shows each target’s name, address, and sign-in method. In a narrow terminal, the details are stacked. Enter a target number to connect directly or **Q** to quit.

Enter **O** to open `Options`. Press **Enter** there to return to the overview. When adding or editing a target, press **Enter** to accept the value in brackets or **!** to cancel. You can correct invalid entries in the field where they occur.

| Input | Menu label | Action |
| --- | --- | --- |
| **N** | New | Add a target. |
| **A** | Automatic updates | Toggle automatic startup update checks on or off (default: on). |
| **U** | Check for updates | Manually check GitHub for a new release and offer installation. |
| **S** | Search | Live full-text search across names, hosts, usernames, ports, and login methods. Matches update as you type; multiple words can match different fields. **Enter** applies the filter, **Esc** cancels, and **Backspace** deletes characters. Clear the term and press Enter to show all targets. In non-interactive terminals, enter a complete search term as before. |
| **B** | Edit | Select a target to edit. Renaming a target preserves its key. If only the port changes, press Enter to keep the key and verify it on the new port at the next connection, or choose **n** to set up a different one. |
| **L** | Delete | Select a target and confirm with **y** to remove it from the list. |
| **I** | Import | Load targets from an exported JSON file. Targets with existing names are skipped. |
| **E** | Export | Save all targets to a new JSON file, even when a search filter is active. |

PowerShell and Bash use the same JSON export format. The file contains target names, hosts, usernames, ports, and sign-in methods. Public and private keys, passwords, local key associations, and OpenSSH configuration stay on the original device. On the first connection to an imported target, the manager sets up a new managed key if needed. Targets set to **OpenSSH** use the configuration on the current machine.

Target profiles are stored as `ziel-*.json` files under `~/.ssh/ssh-manager/` in your home directory. The same folder holds the keys generated by the manager. Server passwords are never saved. Removing a target leaves its local key files and the corresponding authorization on the server in place.
