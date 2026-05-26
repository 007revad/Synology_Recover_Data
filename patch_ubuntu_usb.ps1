# patch_ubuntu_usb.ps1
# Synology_Recover_Data - Ubuntu USB kernel patch
# Adds kernel 4.15.0-108-generic boot entry to Ubuntu 19.10 USB drive
# Required to mount Synology btrfs volumes (kernel 4.15.0-109+ blocks mounting)
#
# GitHub: https://github.com/007revad/Synology_Recover_Data

$ErrorActionPreference = "Stop"

$KernelVersion = "4.15.0-108-generic"
$KernelFile    = "vmlinuz-$KernelVersion"

$NewMenuEntry = @"
menuentry "Try Ubuntu (kernel 4.15.0-108)" {
    set gfxpayload=keep
    linux   /casper/vmlinuz-$KernelVersion persistent file=/cdrom/preseed/ubuntu.seed quiet splash ---
    initrd  /casper/initrd
}

"@

Write-Host ""
Write-Host "Synology Recover Data - Ubuntu USB kernel patch" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Find vmlinuz in the same directory as this script
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$kernelSrc = Join-Path $ScriptDir $KernelFile

if (-not (Test-Path $kernelSrc)) {
    Write-Host "ERROR: $KernelFile not found in script directory." -ForegroundColor Red
    Write-Host "Make sure $KernelFile is in the same folder as this script." -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# List removable drives to help user identify the correct one
Write-Host "Removable drives currently available:" -ForegroundColor Cyan
$removableDrives = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 }
if ($removableDrives) {
    foreach ($drive in $removableDrives) {
        $size = [math]::Round($drive.Size / 1GB, 0)
        $label = if ($drive.VolumeName) { $drive.VolumeName } else { "No label" }
        Write-Host "  $($drive.DeviceID) - $label ($size GB)" -ForegroundColor White
    }
} else {
    Write-Host "  No removable drives found." -ForegroundColor Yellow
}
Write-Host ""

# Prompt for drive letter
Write-Host "Enter the drive letter of your Ubuntu 19.10 USB drive (e.g. G): " -ForegroundColor Cyan -NoNewline
$letter = Read-Host
$letter = $letter.Trim().TrimEnd(':').ToUpper()
$UsbDrive = "${letter}:"

Write-Host ""

# Verify it looks like the correct drive
$grubCfg   = "$UsbDrive\boot\grub\grub.cfg"
$casperDir = "$UsbDrive\casper"

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

# Check if already patched
$grubContent = [System.IO.File]::ReadAllText($grubCfg)
if ($grubContent -match "vmlinuz-$KernelVersion") {
    Write-Host ""
    Write-Host "USB drive is already patched with kernel $KernelVersion." -ForegroundColor Green
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 0
}

# Copy vmlinuz to USB casper folder
$kernelDest = "$casperDir\$KernelFile"
Write-Host "Copying $KernelFile to USB drive..." -ForegroundColor Cyan
try {
    Copy-Item $kernelSrc $kernelDest -Force
} catch {
    Write-Host "ERROR: Failed to copy $KernelFile to USB drive." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# Verify copy
if (-not (Test-Path $kernelDest)) {
    Write-Host "ERROR: $KernelFile not found on USB drive after copy." -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}
$fileSize = (Get-Item $kernelDest).Length
if ($fileSize -lt 1MB) {
    Write-Host "ERROR: Copied file is too small ($fileSize bytes), copy may have failed." -ForegroundColor Red
    Remove-Item $kernelDest -Force -ErrorAction SilentlyContinue
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "Copied $KernelFile successfully ($([math]::Round($fileSize / 1MB, 1)) MB)." -ForegroundColor Green

# Patch grub.cfg - insert new menu entry after "set timeout=X" line
Write-Host "Patching grub.cfg..." -ForegroundColor Cyan
$newContent = $grubContent -replace "(set timeout=\d+\r?\n)", "`$1$NewMenuEntry"
if ($newContent -eq $grubContent) {
    Write-Host "ERROR: Could not find 'set timeout' line in grub.cfg." -ForegroundColor Red
    Write-Host "grub.cfg may have been modified already or has an unexpected format." -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# Write patched grub.cfg without BOM (required for GRUB to parse correctly)
[System.IO.File]::WriteAllText($grubCfg, $newContent, [System.Text.UTF8Encoding]::new($false))
Write-Host "grub.cfg patched successfully." -ForegroundColor Green

Write-Host ""
Write-Host "USB drive patched successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Safely eject the USB drive" -ForegroundColor White
Write-Host "  2. Connect your Synology drives to your PC" -ForegroundColor White
Write-Host "  3. Boot from the USB drive" -ForegroundColor White
Write-Host "  4. Select 'Try Ubuntu (kernel 4.15.0-108)' from the boot menu" -ForegroundColor White
Write-Host "  5. Run the syno_recover_data.sh script" -ForegroundColor White
Write-Host ""
Read-Host "Press Enter to exit"
