# Troubleshooting Metasploit Framework Installation on Termux with Ruby 3.4+

This document outlines common errors encountered when installing Metasploit Framework on Termux, particularly when using recent Ruby versions (like Ruby 3.4.0, which is often the default in Termux). It provides step-by-step solutions for each issue, based on a real-world troubleshooting session.

**Disclaimer:** Metasploit Framework is a powerful tool. Use it only for ethical hacking, penetration testing, and security research on systems you have explicit permission to test. Unauthorized access is illegal.

---

## 1. Prerequisites and Initial Setup

Before starting the troubleshooting, ensure you have:

*   **Termux App:** Downloaded from **F-Droid** (recommended for latest updates and stability).
*   **Sufficient Storage:** At least 5-7 GB of free internal storage.
*   **Updated Termux:**
    ```bash
    pkg update && pkg upgrade -y
    ```
*   **Granted Storage Permissions:**
    ```bash
    termux-setup-storage
    ```
    (Allow when prompted)
*   **Installed Essential Packages:**
    ```bash
    pkg install wget curl git python ruby openssh postgresql nano -y
    ```
    (Note: `nano` is the text editor used for patching files.)
*   **Cloned Metasploit Framework:** (Often done via an installer script, e.g., `hax4us`).
    If you haven't, a common method is:
    ```bash
    git clone https://github.com/hax4us/Metasploit_termux.git
    cd Metasploit_termux
    chmod +x metasploit.sh
    ./metasploit.sh
    ```
    After the script finishes, Metasploit Framework will typically be located in `~/metasploit-framework`. Navigate into it:
    ```bash
    cd ~/metasploit-framework
    ```

---

## 2. General Troubleshooting Advice

*   **Patience is Key:** Many steps, especially `bundle install`, will take a long time.
*   **After ANY file modification (`.gemspec`, `.rb` files):**
    *   Always run `rm Gemfile.lock` from the `~/metasploit-framework` directory.
    *   Then, run `bundle install`.
*   **If PostgreSQL is stuck/crashed:**
    *   Check running processes: `ps aux | grep postgres`
    *   Note the main process ID (PID, usually the first one in the list for the `postgres` command).
    *   Kill it: `kill <PID>` (e.g., `kill 12345`).
    *   Remove any leftover lock files: `rm -f $PREFIX/var/lib/postgresql/postmaster.pid` and `rm -f /data/data/com.termux/files/home/.msf4/db/postmaster.pid` (the latter is for `msfdb`'s own database).
*   **Reboot your phone:** For persistent `ThreadError`s or resource issues during intensive steps (like `msfdb init`), a full phone reboot can clear up RAM and processes.
*   **Keep Termux in the foreground:** During long operations like `bundle install` or `msfdb init`, ensure Termux is the active app and your screen stays on.

---

## 3. Specific Issues and Solutions

The following issues are listed in a common sequence you might encounter them.

### Issue 1: `nokogiri` Build Failure & Old `Bundler` Incompatibility

*   **Symptoms:**
    *   `ERROR: Error installing nokogiri: ERROR: Failed to build gem native extension.`
    *   Errors like `incompatible function pointer types` related to `libxml2`.
    *   `uninitialized constant DidYouMean::SPELL_CHECKERS (NameError)` when Bundler tries to restart.
*   **Root Cause:** The Metasploit Framework (or its `Gemfile.lock`) specifies an older `nokogiri` version (e.g., 1.12.5) that is incompatible with newer `libxml2` APIs in Termux. Also, Bundler itself might be an older version not fully compatible with modern Ruby.
*   **Solution:** Update `nokogiri` and let Bundler rebuild its lockfile.
    1.  Navigate to Metasploit: `cd ~/metasploit-framework`
    2.  Remove old lockfile: `rm Gemfile.lock`
    3.  Edit `metasploit-framework.gemspec`: `nano metasploit-framework.gemspec`
    4.  Find the line `spec.add_runtime_dependency 'nokogiri', ...`
    5.  Change it to: `spec.add_runtime_dependency 'nokogiri', '~> 1.16'` (or newer, e.g., `~> 1.18`)
    6.  Save and exit `nano`: `Ctrl+O`, `Enter`, `Ctrl+X`.
    7.  Run Bundler: `bundle install`

### Issue 2: `packetfu` `Regexp.new` `ArgumentError`

*   **Symptoms:**
    *   `ArgumentError: wrong number of arguments (given 3, expected 1..2)` specifically pointing to `packetfu` or `lib/net/dns/rr.rb`.
    *   `Could not find compatible versions` for `packetfu` even after `gemspec` update.
*   **Root Cause:** The `Regexp.new` method in Ruby 3.4.0 changed its signature, making older `packetfu` versions (and Metasploit's own code) incompatible. The initial range fix might still hit conflicts with `pcaprub`.
*   **Solution:** Broaden the version constraints for both `packetfu` and `pcaprub` in `metasploit-framework.gemspec`.
    1.  Navigate to Metasploit: `cd ~/metasploit-framework`
    2.  Remove old lockfile: `rm Gemfile.lock`
    3.  Edit `metasploit-framework.gemspec`: `nano metasploit-framework.gemspec`
    4.  Find `spec.add_runtime_dependency 'packetfu', ...` and change to:
        `spec.add_runtime_dependency 'packetfu', '~> 2.0'`
    5.  Find `spec.add_runtime_dependency 'pcaprub', ...` and change to:
        `spec.add_runtime_dependency 'pcaprub', '~> 0.13.1'`
    6.  Save and exit `nano`: `Ctrl+O`, `Enter`, `Ctrl+X`.
    7.  Run Bundler: `bundle install`

### Issue 3: `gem install <gem>` or `bundle install` reports "Could not find a valid gem... in any repository"

*   **Symptoms:** Even though the gem clearly exists on rubygems.org, Bundler/Gem cannot find it.
*   **Root Cause:** The RubyGems source configuration in Termux might be corrupted or outdated, or there's a transient network/cache issue.
*   **Solution:** Clear and re-add the official RubyGems source.
    1.  Go to home directory: `cd ~`
    2.  Clear all existing sources: `gem sources --clear-all`
    3.  Add the official source: `gem sources --add https://rubygems.org/`
    4.  Verify sources: `gem sources` (should show `https://rubygems.org/`)
    5.  Navigate back to Metasploit: `cd ~/metasploit-framework`
    6.  Remove old lockfile: `rm Gemfile.lock`
    7.  Run Bundler: `bundle install`

### Issue 4: `LoadError: cannot load such file -- <gem_name>` (e.g., `abbrev`, `net/smtp`, `ostruct`, `benchmark`, `syslog`)

*   **Symptoms:** `msfconsole` crashes with `LoadError` for gems that were previously part of Ruby's standard library but are now externalized in Ruby 3.1.0 and later (e.g., `abbrev`, `net/smtp`, `ostruct`, `benchmark`, `syslog`).
*   **Root Cause:** Metasploit expects these gems to be globally available by default, but Ruby 3.x requires them to be explicitly listed as dependencies.
*   **Solution:** Add these gems as runtime dependencies in `metasploit-framework.gemspec`.
    1.  Navigate to Metasploit: `cd ~/metasploit-framework`
    2.  Remove old lockfile: `rm Gemfile.lock`
    3.  Edit `metasploit-framework.gemspec`: `nano metasploit-framework.gemspec`
    4.  Add the following lines under other `spec.add_runtime_dependency` entries (e.g., near the end of the runtime dependencies block):
        ```ruby
        spec.add_runtime_dependency 'abbrev'
        spec.add_runtime_dependency 'benchmark'
        spec.add_runtime_dependency 'net-smtp'
        spec.add_runtime_dependency 'ostruct'
        spec.add_runtime_dependency 'syslog' # If this specific warning appears
        ```
    5.  Save and exit `nano`: `Ctrl+O`, `Enter`, `Ctrl+X`.
    6.  Run Bundler: `bundle install`

### Issue 5: `lib/net/dns/rr.rb` `Regexp.new` `ArgumentError` (Metasploit Core File)

*   **Symptoms:** `ArgumentError: wrong number of arguments (given 3, expected 1..2)` pointing to `/data/data/com.termux/files/home/metasploit-framework/lib/net/dns/rr.rb:74`.
*   **Root Cause:** Metasploit's own source code (not an external gem) uses `Regexp.new` with a third argument (e.g., `"n"`) which is no longer supported in Ruby 3.4.0.
*   **Solution:** Directly patch the Metasploit source file.
    1.  Navigate to Metasploit: `cd ~/metasploit-framework`
    2.  Edit the file: `nano lib/net/dns/rr.rb`
    3.  Go to line 74 (`Ctrl+Shift+_` then type `74` and `Enter`).
    4.  Find the line similar to:
        `RR_REGEXP = Regexp.new("...", Regexp::IGNORECASE, "n")`
        or `RR_REGEXP = Regexp.new("...", nil, "n")`
    5.  **Remove the third argument (and the comma before it).** The line should end with `Regexp::IGNORECASE)`:
        `RR_REGEXP = Regexp.new("^\x01\x80\xc2\x00\x00[\x0e\x03\x00]", Regexp::IGNORECASE)`
        *(Note: The actual regex string is very long and wrapped; ensure you only remove the final `, "n")` or `, nil, "n")` part).*
    6.  **Carefully Save and exit `nano`:** `Ctrl+O`, `Enter`, `Ctrl+X`. (Verify with `head -n 74 lib/net/dns/rr.rb | tail -n 1`).
    7.  (Optional, but good practice): `rm Gemfile.lock && bundle install`

### Issue 6: `undefined local variable or method 's'` in `metasploit-framework.gemspec`

*   **Symptoms:** `[!] There was an error while loading metasploit-framework.gemspec: undefined local variable or method 's' for main.`
*   **Root Cause:** A typo was introduced during previous edits to `metasploit-framework.gemspec`, using `s.add_runtime_dependency` instead of `spec.add_runtime_dependency`.
*   **Solution:** Correct the variable name in `metasploit-framework.gemspec`.
    1.  Navigate to Metasploit: `cd ~/metasploit-framework`
    2.  Edit `metasploit-framework.gemspec`: `nano metasploit-framework.gemspec`
    3.  Find any lines starting with `s.add_runtime_dependency`.
    4.  Change `s` to `spec` for all such lines: `spec.add_runtime_dependency 'abbrev'`
    5.  Save and exit `nano`: `Ctrl+O`, `Enter`, `Ctrl+X`.
    6.  Remove old lockfile: `rm Gemfile.lock`
    7.  Run Bundler: `bundle install`

### Issue 7: `msfdb init` fails with `PG::UndefinedTable` or `ThreadError`

*   **Symptoms:** `PG::UndefinedTable: ERROR: relation "workspaces" does not exist` or `ThreadError: can't alloc thread` during "Creating initial database schema" when running `./msfdb init`.
*   **Root Cause:** The PostgreSQL database schema (tables) was not successfully created or was corrupted from a previous failed attempt. `ThreadError` often indicates resource limitations during the intensive schema creation process.
*   **Solution:** Clean up any old database, free up resources, and retry `msfdb init`.
    1.  **Kill ALL PostgreSQL processes:**
        *   Check for running processes: `ps aux | grep postgres`
        *   For each `postgres` process listed (except `grep postgres` itself), note its PID and kill it: `kill <PID>`
    2.  **Remove any partially created Metasploit database files:**
        `rm -rf /data/data/com.termux/files/home/.msf4/db`
    3.  **(CRUCIAL for `ThreadError`) Reboot your Android phone.**
    4.  After reboot, open Termux immediately and keep it in the foreground.
    5.  Navigate to Metasploit: `cd ~/metasploit-framework`
    6.  Run `msfdb init`: `./msfdb init`
        *   When prompted: `[?] Would you like to init the webservice? (Not Required) [no]:` type `no` and press `Enter`.
        *   When prompted: `[?] Would you like to delete your existing data and configurations? []:` type `yes` and press `Enter`.

### Issue 8: `Psych::AliasesNotEnabled` in `msfdb` or `lib/msf/core/db_manager.rb`

*   **Symptoms:** `Alias parsing was not enabled. To enable it, pass `aliases: true` to `Psych::load` or `Psych::safe_load`. (Psych::AliasesNotEnabled)` pointing to `msfdb` or `lib/msf/core/db_manager.rb`.
*   **Root Cause:** Newer Ruby versions (3.1+) disable YAML alias parsing by default for security. Metasploit's scripts/code use YAML files with aliases without explicitly enabling parsing.
*   **Solution:** Patch the relevant files to enable `aliases: true` for YAML loading.
    1.  **Stop PostgreSQL:** `pg_ctl -D $PREFIX/var/lib/postgresql stop`
    2.  **Navigate to Metasploit:** `cd ~/metasploit-framework`
    3.  **Patch `msfdb` script:**
        *   `nano msfdb`
        *   Go to line 273 (or search for `YAML.load`).
        *   Change `config = YAML.load(File.read(@db_conf))` to:
            `config = YAML.load(File.read(@db_conf), aliases: true)`
        *   Save and exit `nano`.
    4.  **Patch `lib/msf/core/db_manager.rb`:**
        *   `nano lib/msf/core/db_manager.rb`
        *   Go to line 194 (or search for `YAML.load_file`).
        *   Change `dbinfo = YAML.load_file(configuration_pathname) || {}` to:
            `dbinfo = YAML.load_file(configuration_pathname, aliases: true) || {}`
        *   Save and exit `nano`.
    5.  **Remove any partially created Metasploit database:** `rm -rf /data/data/com.termux/files/home/.msf4/db` (needed because the previous `msfdb init` might have failed halfway due to this issue).
    6.  **Run `msfdb init` again:** `./msfdb init` (answer `no` for webservice, `yes` for delete existing data).

---

## 4. Final Launch

After successfully resolving all the issues above (especially `msfdb init` completing without fatal errors), you can finally launch Metasploit:

1.  **Start PostgreSQL Server:** (if it's not already running from `msfdb init`)
    ```bash
    pg_ctl -D $PREFIX/var/lib/postgresql start
    ```
2.  **Launch Metasploit Console:**
    ```bash
    ./msfconsole
    ```

You should now see the Metasploit banner and the `msf6 >` prompt!

---

## 5. Ongoing Maintenance

*   **Starting Metasploit:** Remember to run `pg_ctl -D $PREFIX/var/lib/postgresql start` (or `./msfdb start`) before `./msfconsole` each time.
*   **Stopping Metasploit:** Always `exit` from `msfconsole`, and then `pg_ctl -D $PREFIX/var/lib/postgresql stop` (or `./msfdb stop`).
*   **Updating Metasploit:** Use `msfupdate` inside the console, but be aware that major updates can sometimes re-introduce dependency issues that require similar troubleshooting. You might also want to `git pull` in the `~/metasploit-framework` directory for the latest code.
*   **Performance:** Metasploit is resource-intensive. Close other apps on your phone and use an external keyboard for a better experience.
