Ubuntu Server Minimal Setup Script
===========================================

**Version:** 1.0**Target:** Ubuntu Server Minimal (netplan + systemd)**Purpose:** Explain how to use the setup\_system.sh script (interactive and unattended), detail what each step does and why, list required packages, describe environment variables and CLI flags, and explain design philosophy and security considerations.

Table of contents
-----------------

1.  Quick summary / TL;DR
    
2.  What this script does (high level)
    
3.  Requirements & packages used
    
4.  How to run — interactive and unattended (examples)
    
5.  All environment variables and CLI flags (full list + default values)
    
6.  Step-by-step explanation of what each step does and how it works
    
7.  Files the script creates and why (permissions)
    
8.  Error handling & troubleshooting tips
    
9.  Security recommendations & cleanup (best practices)
    
10.  Philosophy — why this script exists and design rationale
    
11.  Appendix — example runs and advanced usage
    

1 — Quick summary / TL;DR
=========================

This script automates initial provisioning tasks on an Ubuntu Server Minimal host:

*   Optionally update the system (apt update && apt upgrade -y)
    
*   Optionally set root password (typed or randomized) and save it to /root/.root.pass
    
*   Optionally create a new user with a typed or randomized password and save it to /root/..pass
    
*   Optionally change system hostname
    
*   Optionally configure a static IPv4 address via **netplan**
    
*   Interactive by default; also supports unattended (non-interactive) mode via environment variables or CLI flags
    
*   Color-coded output for important messages (errors, passwords, step headers)
    

Run with sudo bash setup\_system.sh for interactive mode, or use --unattended and environment variables/flags for automated provisioning.

2 — What this script does (high level)
======================================

The script is a multi-step provisioning tool intended for a freshly installed Ubuntu Server Minimal machine. It provides a repeatable, safe way to:

*   Harden access (set or rotate root password)
    
*   Create a human account (with sudo privileges)
    
*   Configure basic networking (optionally switch to static IP via netplan)
    
*   Standardize hostnames
    
*   Save generated credentials in /root with restricted permissions for later retrieval
    

It aims to reduce manual, error-prone steps when bringing up a new headless server.

3 — Requirements & packages used
================================

**OS compatibility:** Ubuntu Server (versions that use netplan and systemd). The script assumes apt, hostnamectl, netplan, systemd, and typical core command-line utilities are present. It should work on most modern Ubuntu Server releases.

**Packages used (recommended to be available):**

*   openssl — for secure random password generation. If openssl is not installed, the script falls back to /dev/urandom.
    
    *   Install: sudo apt install -y openssl
        
*   netplan — used to apply static IPv4 configuration; present on standard Ubuntu Server.
    
*   sudo, hostnamectl, adduser, chpasswd, usermod, systemctl, ip, awk, tee, tr — utilities expected to exist in a standard server install.
    

**Notes:**

*   openssl is optional but recommended because openssl rand provides cryptographically good randomness and may avoid subtle issues with /dev/urandom on some embedded environments.
    
*   The script uses netplan apply. If your system uses a different network renderer or a cloud-provider-managed network config, adjust accordingly.
    

4 — How to run
==============

### Interactive (recommended for manual setups)

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   sudo bash setup_system.sh   `

This will prompt you at each step with defaults shown. For interactive sessions you can accept defaults by pressing Enter.

### Fully unattended (non-interactive)

You can run the script in non-interactive mode by passing --unattended or setting UNATTENDED=1. Supply environment variables or flags to control behavior.

**Example — environment variables (unattended):**

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   sudo UNATTENDED=1 \       SET_ROOT_PASS=y ROOT_PASS_MODE=r ROOT_PASS_LEN=14 \       CREATE_USER=y NEWUSER=admin USER_PASS_MODE=r USER_PASS_LEN=12 \       HOSTNAME_NEW=server01 \       SET_STATIC=n \       bash setup_system.sh --unattended   `

**Example — CLI flags:**

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   sudo bash setup_system.sh --unattended --hostname=server01 --user=deploy --static-ip   `

> Note: Flags are parsed for convenience; env vars let you pass values for fields not supported as flags (e.g., password modes, lengths, IPs).

### Logging output

If you'd like to capture everything to a log:

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   sudo bash setup_system.sh 2>&1 | sudo tee /var/log/system-setup.log   `

5 — Environment variables and CLI flags
=======================================

You can control the script via **environment variables** (preferred for automation) or the following **CLI flags**:

### CLI flags

*   \--unattended — run in unattended (non-interactive) mode (also available via UNATTENDED=1)
    
*   \--hostname= — set HOSTNAME\_NEW directly
    
*   \--user= — set NEWUSER directly
    
*   \--user-pass= — set USER\_PASS directly (less secure, visible from process list)
    
*   \--root-pass= — set ROOT\_PASS\_MANUAL directly (less secure)
    
*   \--static-ip — equivalent to SET\_STATIC=y (requires additional env vars to fully configure)
    

> Unknown flags are warned about but not fatal.

### Environment variables (full list)

*   UNATTENDED — 0 or 1. If 1, script will not prompt interactively; will use the provided env vars or defaults. Default: 0.
    
*   SET\_ROOT\_PASS — y/n — whether to set a new root password (interactive default: prompt; unattended default: n if not set)
    
*   ROOT\_PASS\_MODE — r (random) / t (typed). Default: r.
    
*   ROOT\_PASS\_LEN — integer length for randomized root password (default used in script: 14; changeable by env var)
    
*   ROOT\_PASS\_MANUAL — explicit root password string (used in unattended mode if you want to provide a typed password).
    
*   CREATE\_USER — y/n — whether to create a new user (interactive default: prompt; unattended default: n if not set)
    
*   NEWUSER — username to create (e.g., admin)
    
*   USER\_PASS\_MODE — r (random) / t (typed) — default r
    
*   USER\_PASS\_LEN — length for randomized user password (default used in script: 11; changeable)
    
*   USER\_PASS — explicit password string for the new user (in unattended mode)
    
*   HOSTNAME\_NEW — hostname to set (defaults to current hostname)
    
*   SET\_STATIC — y/n — whether to configure a static IPv4 address
    
*   IPADDR, GATEWAY, DNS, SEARCH — network parameters used when SET\_STATIC=y. If unset, the script tries to show and use current system values as defaults.
    
*   NETPLAN\_FILE — path where the netplan config will be written (script default: /etc/netplan/01-netcfg.yaml)
    

**Security note:** Passing passwords on the command-line (e.g. --user-pass, --root-pass) is insecure on multi-user systems, because they may appear in the process list. Prefer to use randomized passwords or provide passwords via secure automation mechanisms (e.g., cloud-init secret injection or configuration management vaults).

6 — Step-by-step explanation (what each step does, and how)
===========================================================

Below is a detailed breakdown of each major section of the script and what the script executes.

### STEP 0 — System update

**What it does:** Runs:

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   sudo apt update && sudo apt upgrade -y   `

**Why:** Brings package lists up-to-date and applies upgrades. Good to do before making configuration changes to ensure the system is not in a partial state with old packages.

**How:** apt update downloads latest package lists; apt upgrade -y performs upgrades. The script wraps this step and prints an error if it fails and continues to later steps.

### STEP 1 — Root password configuration

**What it does (interactive flow):**

*   Asks whether to set a new root password.
    
*   If yes, asks whether to generate a randomized password or enter one manually.
    
    *   If randomized: chooses a length (default 13–15 in earlier version; in the final script ROOT\_PASS\_LEN default is used), generates a secure string using openssl rand (preferred) or /dev/urandom fallback, saves it to /root/.root.pass, sets root's password using chpasswd and sets file perms to 600.
        
    *   If manual: read password securely from stdin (no echo) and set with chpasswd; if unattended and manual password provided via env var, it will use that.
        

**Commands used:**

*   openssl rand -base64 N | tr -dc 'A-Za-z0-9' | head -c — for generating alphanumeric pass
    
*   tr -dc 'A-Za-z0-9'
    
*   echo "root:" | chpasswd — sets root password
    
*   tee /root/.root.pass and chmod 600 /root/.root.pass — saves password and restricts access
    

**Why:**

*   Allow rotation of root password in a reproducible, auditable way while keeping the password secure and readable only by root.
    

**Security note:** Storing passwords in /root is convenient but should be considered a temporary convenience. Best practice: rotate these passwords after initial login or move to an encrypted secret store.

### STEP 2 — Create new user

**What it does (interactive flow):**

*   Optionally creates a new user account (prompts for username).
    
*   Prompts for password mode: randomized or typed. If randomized, it generates a password (default length 11) and saves it to /root/..pass. If typed, secure input is read.
    
*   Creates the user (adduser --disabled-password --gecos "" ), sets the password via chpasswd, and adds the user to sudo group; if usermod -aG sudo fails it attempts usermod -aG wheel for distributions using wheel.
    

**Commands used:**

*   id — check if user exists
    
*   adduser --disabled-password --gecos "" — create user without setting the password (we set it next)
    
*   echo ":" | chpasswd — set user password
    
*   usermod -aG sudo — add to sudo group
    

**Why:**

*   Provides a human account with privileges (instead of using root for day-to-day tasks) while enabling automation for initial password creation.
    

**Notes:**

*   If the user already exists, the script skips creation and warns.
    
*   For least privilege and reproducible automation, you may prefer to set up SSH keys for the user rather than a password.
    

### STEP 3 — Hostname setup

**What it does:**

*   Prompts for new hostname. Defaults to current hostname if user presses Enter.
    
*   If new hostname differs, writes it to /etc/hostname, runs hostnamectl set-hostname , and restarts systemd-logind.service to reflect changes in the login sessions.
    

**Commands used:**

*   hostname and hostnamectl set-hostname
    
*   tee /etc/hostname
    
*   systemctl restart systemd-logind.service (best-effort; true allowed on failure)
    

**Why:**

*   Keeps host identifiers organized across your infrastructure and ensures things like SSH and logs show the new name.
    

### STEP 4 — Static IP configuration (via netplan)

**What it does:**

*   Asks whether to set a static IPv4 address.
    
*   Detects active network interface (via ip -o -4 route show to default | awk '{print $5}'), current IP/gateway/DNS values, and uses those values as defaults for prompts.
    
*   Writes a netplan YAML file (default path /etc/netplan/01-netcfg.yaml) containing:
    

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   network:    version: 2    renderer: networkd    ethernets:      :        dhcp4: no        addresses:          - /24        gateway4:         nameservers:          addresses: []          search: []   `

*   Runs netplan apply. If netplan apply fails, it attempts to revert by enabling DHCP in that file and reapply.
    

**Commands used:**

*   ip, awk, hostname -I, grep nameserver /etc/resolv.conf for detection
    
*   tee /etc/netplan/01-netcfg.yaml to write YAML
    
*   sudo netplan apply to apply configuration
    

**Why:**

*   Static IP is often required for servers (port forwarding, service discovery). Netplan is Ubuntu's canonical way to manage persistent network config.
    

**Caveats:**

*   This script writes a very simple netplan file with /24 netmask. If your network uses a different prefix, or needs VLANs, bridges, or IPv6, you must edit the netplan file accordingly.
    
*   On cloud instances or providers that manage the network config, overriding netplan may break provider-managed settings. Double-check before applying.
    

### STEP 5 — Finishing up

**What it does:**

*   Optionally switches to the new user (sudo -i -u ) in interactive session when requested.
    
*   Lists created password files (/root/.\*.pass) for the admin to confirm saved credentials.
    

**Why:**

*   Gives quick access to the user environment and displays where credentials were stored.
    

7 — Files created by the script
===============================

**Password files (if created):**

*   /root/.root.pass — contains the root password if generated (or sometimes overwritten when manual root password provided and the script saves it).
    
*   /root/..pass — generated user password for .
    

**Permissions**

*   The script sets chmod 600 on password files to restrict them to root access only (read/write for owner).
    

**Netplan**

*   /etc/netplan/01-netcfg.yaml — static IP YAML created/overwritten if SET\_STATIC is enabled.
    

**/etc/hostname**

*   If the hostname is changed, /etc/hostname is updated with the new name.
    

8 — Error handling & troubleshooting
====================================

**General model**

*   The script uses set -euo pipefail to detect many classes of failure.
    
*   For steps that may legitimately fail (e.g., netplan apply), the script attempts recovery (revert to DHCP) and logs an error but continues to next steps.
    
*   On any failure the script prints an error message and moves on — it does **not** abort the whole run in most cases.
    

**Common issues and fixes**

*   apt locked (Could not get lock): Another apt process is running. Wait or kill interfering process.
    
*   netplan apply fails and you lose network: boot into rescue or restore /etc/netplan/01-netcfg.yaml to a DHCP config, then netplan apply.
    
*   Interface detection fails (script can't identify interface): set IPADDR, IFACE, etc., explicitly in env vars and modify NETPLAN\_FILE manually if necessary.
    
*   Passwords not being written: ensure the script runs with sudo or root privileges. tee to /root/... requires root.
    
*   adduser fails: user already exists. Use a different username or skip creation.
    

**To debug:**

*   Rerun with logging: sudo bash setup\_system.sh 2>&1 | sudo tee /var/log/system-setup.log and inspect the log.
    
*   Check system logs: journalctl -xe or sudo journalctl -u systemd-networkd.service for network-specific issues.
    

9 — Security recommendations & cleanup
======================================

**Short-term**

*   After the first login, rotate any saved passwords and delete files in /root:
    

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   sudo shred -u /root/.root.pass /root/..pass  # or  sudo rm -f /root/.root.pass /root/..pass   `

*   Prefer to replace password authentication with SSH public-key authentication for the created user. Disable root login over SSH if not needed.
    

**Long-term**

*   Use a secrets manager (HashiCorp Vault, AWS Secrets Manager, Azure Key Vault, etc.) to store and retrieve initial credentials instead of storing them on the host.
    
*   Use automated configuration management (Ansible, Salt, Puppet) or cloud-init for repeatable provisioning in larger deployments.
    
*   Consider using passwd --stdin or chpasswd via secure pipelines — passwords never echo and are only sent on stdin.
    

**Access**

*   Restrict access to /root; ensure only trusted admins can access the system during provisioning.
    

10 — Philosophy — why this script exists and the design choices
===============================================================

**Why this exists**

*   First-boot and initial provisioning of headless or minimal servers is a frequent, repetitive task. This script captures a small, well-scoped set of responsibilities that admins almost always need to take care of:
    
    *   Bring the system up-to-date.
        
    *   Secure the root account and create an administrative user.
        
    *   Set a predictable hostname.
        
    *   Optionally configure network settings for stable reachability.
        

**Design principles**

*   **Small and composable:** It does a few things very well. For complex environments, the script intentionally avoids replacing a proper configuration management system.
    
*   **Idempotent-ish:** It checks for existing users and will skip creation if present, minimizing destructive behavior.
    
*   **Interactive and Unattended:** Supports admin-driven provisioning and automated runs (CI/automation templates).
    
*   **Secure-by-default:** Randomized passwords are generated using openssl if available, and saved to files with 600 permissions. The script discourages insecure practices and notes when they are being used.
    
*   **Fail-forward:** If one step fails, the script logs and continues. The reasoning: partial provisioning is better than stopping mid-run and leaving the system in an unknown state. Admins can then inspect logs and fix specific problems.
    
*   **Transparent:** It writes human-readable files and prints password values so a human can take over quickly if needed. (For production, pair this with an encrypted vault.)
    

**Why not more?**

*   The script intentionally avoids complex constructs (certificates, firewall rules, full user onboarding with SSH keys) because those are environment-specific and best handled by dedicated tools (Ansible, cloud-init, or a secret manager).
    

11 — Appendix: Example runs & advanced usage
============================================

### Example 1 — Interactive full run

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   sudo bash setup_system.sh   `

Follow prompts:

*   update runs
    
*   prompt to set root password → choose r (random)
    
*   prompt to create user → choose y, username admin, choose r (random)
    
*   prompt to set hostname → server01
    
*   prompt to set static IP → n
    
*   finish, optionally switch to new user
    

### Example 2 — Unattended with randomized passwords

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   sudo UNATTENDED=1 \    SET_ROOT_PASS=y ROOT_PASS_MODE=r ROOT_PASS_LEN=14 \    CREATE_USER=y NEWUSER=admin USER_PASS_MODE=r USER_PASS_LEN=12 \    HOSTNAME_NEW=server01 \    SET_STATIC=n \    bash setup_system.sh --unattended   `

*   Root and user passwords will be generated and saved to /root/.root.pass and /root/.admin.pass
    

### Example 3 — Unattended with explicit passwords

> **WARNING:** This exposes passwords in process list and shell history; use only in controlled automation.

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   sudo UNATTENDED=1 \    SET_ROOT_PASS=y ROOT_PASS_MODE=t ROOT_PASS_MANUAL='S3cureP@ssw0rd' \    CREATE_USER=y NEWUSER=deployer USER_PASS_MODE=t USER_PASS='DeployPass123' \    HOSTNAME_NEW=deploy-01 \    SET_STATIC=n \    bash setup_system.sh --unattended   `

### Capture output to log

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   sudo bash setup_system.sh 2>&1 | sudo tee /var/log/system-setup.log   `

Then inspect:

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   sudo less /var/log/system-setup.log   `

Final notes
-----------

*   **Do not** rely on this script as the sole security measure. Use it to bootstrap systems and then apply your organization's security baseline.
    
*   If you want, I can:
    
    *   Add optional logging into /var/log/system-setup.log from inside the script.
        
    *   Replace password storage with GPG-encrypted files.
        
    *   Add SSH key injection support (preferred over passwords).
        
    *   Convert this into a cloud-init user-data script for fully automated cloud provisioning.
        

If you want any of the above improvements (GPG encryption, SSH key support, log integration, Ansible role conversion, or cloud-init version), tell me which and I’ll produce the code and examples.
