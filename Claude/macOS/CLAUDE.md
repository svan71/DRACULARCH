# CLAUDE.md (macOS)

Guidance for Claude Code on Steve's Macs (M4 Pro + two Hackintoshes).

## Preferences — READ FIRST
- **Bash with ble.sh** on all platforms. UX, POSIX compatible.
- Simple and effective, no over-engineering.
- Ask questions one at a time.
- Hates typing — keep commands short.
- Script output must be themed — use color variables.
- **NEVER put .sh scripts in the DRACULARCH repo** — scripts live on USB/Synology only.

## Repo + Sync Conventions

**DRACULARCH** = github.com/svan71/DRACULARCH. Local clone at `~/Dracularch/`.

**"sync" means:** copy to repo → git push → copy to USB.

**USB label format:** `ARCH_YYYYMM` (changes monthly). macOS path: `/Volumes/ARCH_YYYYMM/`.

**Synology (macOS):** `/Volumes/external/WEB Scripts/Scripts/`.

## Hardware
- Intel 14900K, 32GB, Samsung Odyssey G8 4K@240Hz (Hackintosh + Windows + Arch)
- AMD 9950X3D, 64GB (Hackintosh + Arch)
- Mac M4 Pro, 24GB

## Arch work from Mac
For any Arch / Dracula.sh / Mokka.sh / Linux-specific guidance, read `~/Dracularch/Claude/CLAUDE.md`. Do not duplicate that content here.

---

## macOS

### bash.sh (installer)
Lives on USB/Synology, NEVER in repo. Idempotent — safe to re-run. Read the script directly when working on it; don't rely on remembered behavior.

### Power Management (M4 Pro — prevent unwanted wakes)
```bash
sudo pmset -a powernap 0        # biggest offender (mDNSResponder, dasd, NotificationCenter)
sudo pmset -a womp 0            # Wake on LAN
sudo pmset -a proximitywake 0   # iPhone/Watch proximity
sudo pmset -a tcpkeepalive 0    # apps holding connections (breaks Find My during sleep)
sudo pmset schedule cancelall   # Calendar/Focus/Analytics wakes
```

### SMB optimization
`/etc/nsmb.conf`: `signing_required=no`, `validate_neg_off=yes`, `smb_read/write=4194304`, `mc_on=yes`, `mc_prefer_wired=yes`, `dir_cache_max_cnt=0`. Result: ~285 MB/s to Synology.

### Firefox userChrome (macOS)
Enable via `toolkit.legacyUserProfileCustomizations.stylesheets = true` in `user.js` (Betterfox v144 base). Colors/spacing live in the CSS file itself — read it.

### createinstallmedia EFI bug (Tahoe+)
Sometimes creates USB with EFI partition present in GPT but not formatted FAT32 → `diskutil mount` silently fails. Fixes:
- Post-fix: `sudo newfs_msdos -F 32 -v EFI /dev/diskNs1` then mount
- Pre-fix: erase USB fully as GPT/JHFS+ before running createinstallmedia

---

## Hackintosh

Two machines, both running **Official Acidanthera OpenCore 1.0.7**, SMBIOS `MacPro7,1`, macOS Tahoe 26.x.

### Shared gotchas (both)
- **NO_ACPI variant is NOT required.** All SSDTs use `_OSI("Darwin")` wrapping + config uses only standard schema keys. Official OC validates clean.
- **OCAT warning**: may strip unrecognized keys from newer OC. Use ProperTree or a text editor for config edits.
- **PickerVariant uses forward slash**: `BlackOSX/BsxM1` (NOT backslash).
- **Theme requires populated `Resources/Font/` and `Resources/Label/`** — missing files = silent theme fail.
- **ocvalidate** before installing: `~/Desktop/OpenCore_OFFICIAL_107/Utilities/ocvalidate/ocvalidate /Volumes/EFI/EFI/OC/config.plist`
- **Clean EFI metadata before zipping/copying**: `dot_clean /Volumes/EFI/EFI`

### Intel (14900K, Z790 Aorus Master, RX 6950 XT)
- Ethernet: **LucyRTL8125Ethernet** for RTL8125B.
- CPUID spoof: Raptor Lake → Comet Lake (required for macOS P-state tables).
- iGPU disabled via DeviceProperties (`disable-gpu` on PciRoot(0x0)/Pci(0x2,0x0)).
- Boot args: `npci=0x2000`.
- `UEFI:Output:Resolution` = `Max`, `UIScale` = `0` (auto). Works; don't "fix" based on stale notes.
- Performance verified: XCPM active, 5.5GHz all-core, 6.2GHz single. Don't tweak CPUFriend — already hits BIOS ceiling.

### AMD (7950X3D, RX 6600)
- AMD-specific kexts: `AMDRyzenCPUPowerManagement`, `AppleMCEReporterDisabler`, `AMFIPass`.
- 16 AMD Vanilla kernel patches (CaseySJ IOPCIFamily AM5, Algrey/Zormeister PAT fix 15.0+). `MaxKernel: 25.99.99`.
- Ethernet: `AppleIntelI210Ethernet` 2.3.1 for Intel I225-V.
- Resizable BAR enabled but GPU reports 256MB (BIOS or NootRX limitation).
- SSDT-ANS has 4 NVMe entries incl. Predator GM7000 on RP09 (spoofed Samsung `pci144d,a806`).

### EFI update workflow
1. Download from github.com/acidanthera/OpenCorePkg/releases
2. Start with new `Docs/Sample.plist`, rename to `config.plist`, migrate settings
3. Replace: `BOOTx64.efi`, `OpenCore.efi`, `Drivers/*.efi`
4. Keep: `ACPI/*.aml`, `Kexts/`, `Resources/`
5. Validate with `ocvalidate`, backup old EFI before replacing

### Useful commands
```bash
sudo diskutil mount disk0s1          # mount EFI
system_profiler SPDisplaysDataType   # check GPU
system_profiler SPEthernetDataType   # check Ethernet
```

---

## Cross-Platform

### Dark Reader (pending)
File: `/Volumes/external/WEB Scripts/Google/Dark-Reader-Settings.json`. Pending: replace all Dracula `#6272A4` selection colors with Catppuccin Mauve `#cba6f7`; replace claude.ai config with Catppuccin Mocha (bg `#11111b`, selection `#c29df1`).

### Ghostty + ble.sh double-prompt (ACTIVE BUG)
Started with Ghostty 1.3.1. Confirmed on macOS + CachyOS. Upstream: [ble.sh issue #684](https://github.com/akinomyoga/ble.sh/issues/684). All local workarounds tried and failed. **Do not attempt new ones.** When fix lands: `cd ~/.local/share/blesh && git pull && make` → restart shell.

