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
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
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
$removableDrives = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 }
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
Write-Host "Enter the drive letter of your Ubuntu 19.10 USB drive (e.g. G): " -ForegroundColor Cyan -NoNewline
$letter   = Read-Host
$letter   = $letter.Trim().TrimEnd(':').ToUpper()
$UsbDrive = "${letter}:"

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
Write-Host "Copied btrfs.ko successfully ($([math]::Round((Get-Item $btrfsDest).Length / 1MB, 1)) MB)." -ForegroundColor Green

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
Write-Host "Copied syno_recover_data.sh successfully." -ForegroundColor Green

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
