# setup_ubuntu_usb.ps1
# Synology_Recover_Data - Ubuntu USB setup
# Copies syno_recover_data.sh and btrfs.ko to Ubuntu 19.10 USB drive
#
# GitHub: https://github.com/007revad/Synology_Recover_Data

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "Synology Recover Data - Ubuntu USB setup" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Find files in the same directory as this script
# Use $PSScriptRoot (works in both PS 5.1 and PS 7); it's always set when
# running as a script, whereas $MyInvocation.MyCommand.Path can be $null
# in some hosts or when the script is dot-sourced.
$ScriptDir  = $PSScriptRoot
$btrfsSrc   = Join-Path $ScriptDir "btrfs.ko"
$recoverSrc = Join-Path $ScriptDir "syno_recover_data.sh"

if (-not (Test-Path $btrfsSrc)) {
    Write-Host "ERROR: btrfs.ko not found in script directory." -ForegroundColor Red
    Write-Host "Make sure btrfs.ko is in the same folder as this script." -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

if (-not (Test-Path $recoverSrc)) {
    Write-Host "ERROR: syno_recover_data.sh not found in script directory." -ForegroundColor Red
    Write-Host "Make sure syno_recover_data.sh is in the same folder as this script." -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# List removable drives to help user identify the correct one
Write-Host "Removable drives currently available:" -ForegroundColor Cyan
# Use Get-CimInstance instead of Get-WmiObject so the script works on both
# Windows PowerShell 5.1 and PowerShell 7.x (Get-WmiObject was removed in PS 7).
$removableDrives = Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType = 2'
if ($removableDrives) {
    foreach ($drive in $removableDrives) {
        $size  = [math]::Round($drive.Size / 1GB, 0)
        $label = if ($drive.VolumeName) { $drive.VolumeName } else { "No label" }
        Write-Host "  $($drive.DeviceID) - $label ($size GB)" -ForegroundColor White
    }
} else {
    Write-Host "  No removable drives found." -ForegroundColor Yellow
}
Write-Host ""

# Prompt for drive letter
# Loop until the user enters a single A-Z letter that maps to an existing drive,
# otherwise an empty/garbage input would produce confusing "could not find :\..." errors below.
do {
    Write-Host "Enter the drive letter of your Ubuntu 19.10 USB drive (e.g. G): " -ForegroundColor Cyan -NoNewline
    $letter = (Read-Host).Trim().TrimEnd(':').ToUpper()
    if ($letter -notmatch '^[A-Z]$') {
        Write-Host "  Please enter a single letter (A-Z)." -ForegroundColor Yellow
        $letter = $null
    } elseif (-not (Test-Path "${letter}:\")) {
        Write-Host "  Drive ${letter}: was not found." -ForegroundColor Yellow
        $letter = $null
    }
} until ($letter)
$UsbDrive = "${letter}:"

# Safety check: if the chosen letter isn't in the removable-drives list, make the
# user explicitly confirm. Guards against accidentally typing a fixed/system drive.
$removableLetters = @($removableDrives | ForEach-Object { $_.DeviceID.TrimEnd(':').ToUpper() })
if ($removableLetters -notcontains $letter) {
    Write-Host ""
    Write-Host "WARNING: ${UsbDrive} is NOT detected as a removable drive." -ForegroundColor Yellow
    Write-Host "Type 'YES' to continue anyway: " -ForegroundColor Yellow -NoNewline
    if ((Read-Host) -ne 'YES') {
        Write-Host "Aborted." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}

Write-Host ""

# Verify it looks like the correct drive
$casperDir = "$UsbDrive\casper"
$grubCfg   = "$UsbDrive\boot\grub\grub.cfg"

if (-not (Test-Path $grubCfg)) {
    Write-Host "ERROR: Could not find $grubCfg" -ForegroundColor Red
    Write-Host "Make sure the drive letter is correct and the USB was created with Rufus." -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

if (-not (Test-Path $casperDir)) {
    Write-Host "ERROR: Could not find $casperDir" -ForegroundColor Red
    Write-Host "Make sure the drive letter is correct and the USB was created with Rufus." -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Found Ubuntu USB drive at ${UsbDrive}" -ForegroundColor Green

# Copy btrfs.ko to USB drive root
$btrfsDest = "$UsbDrive\btrfs.ko"
Write-Host "Copying btrfs.ko to USB drive..." -ForegroundColor Cyan
try {
    Copy-Item $btrfsSrc $btrfsDest -Force
} catch {
    Write-Host "ERROR: Failed to copy btrfs.ko to USB drive." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}
if (-not (Test-Path $btrfsDest)) {
    Write-Host "ERROR: btrfs.ko not found on USB drive after copy." -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}
# Verify the copy by SHA-256 hash, not just by existence. Test-Path returns true
# even on a truncated/corrupt copy, which is a real risk with cheap USB media.
if ((Get-FileHash $btrfsSrc -Algorithm SHA256).Hash -ne (Get-FileHash $btrfsDest -Algorithm SHA256).Hash) {
    Write-Host "ERROR: btrfs.ko on USB drive does not match source (hash mismatch). The copy is corrupt." -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "Copied btrfs.ko successfully ($([math]::Round((Get-Item $btrfsDest).Length / 1MB, 1)) MB, hash-verified)." -ForegroundColor Green

# Copy syno_recover_data.sh to USB drive root
$recoverDest = "$UsbDrive\syno_recover_data.sh"
Write-Host "Copying syno_recover_data.sh to USB drive..." -ForegroundColor Cyan
try {
    Copy-Item $recoverSrc $recoverDest -Force
} catch {
    Write-Host "ERROR: Failed to copy syno_recover_data.sh to USB drive." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}
if (-not (Test-Path $recoverDest)) {
    Write-Host "ERROR: syno_recover_data.sh not found on USB drive after copy." -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}
# Verify the copy by SHA-256 hash (see note above on btrfs.ko).
if ((Get-FileHash $recoverSrc -Algorithm SHA256).Hash -ne (Get-FileHash $recoverDest -Algorithm SHA256).Hash) {
    Write-Host "ERROR: syno_recover_data.sh on USB drive does not match source (hash mismatch). The copy is corrupt." -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "Copied syno_recover_data.sh successfully (hash-verified)." -ForegroundColor Green

Write-Host ""
Write-Host "USB drive setup successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Safely eject the USB drive" -ForegroundColor White
Write-Host "  2. Connect your Synology drives to your PC" -ForegroundColor White
Write-Host "  3. Boot from the USB drive" -ForegroundColor White
Write-Host "  4. Select 'Try Ubuntu without installing' from the boot menu" -ForegroundColor White
Write-Host "  5. Open a terminal and run: sudo bash /cdrom/syno_recover_data.sh" -ForegroundColor White
Write-Host ""
Read-Host "Press Enter to exit"
