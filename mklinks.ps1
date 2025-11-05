
# Set the title for the PowerShell window
$Host.UI.RawUI.WindowTitle = "Addon Linker Script"
# 1. Define the prompt for the platform
$platformMessage = "Which platform do you use for Idle Champions? (Type 'Steam' or 'Epic')"

# 2. Get the platform from the user via text input
$platformInput = Read-Host -Prompt $platformMessage

# 3. Define the prompt for the directory
$dirMessage = "Please enter the directory to install into"

# 4. Get the directory from the user and store it in $baseDir
$baseDir = Read-Host -Prompt $dirMessage

# 5. Set the '$imports' variable based on their platform selection
# We use -imatch for a case-insensitive match (so "steam" or "Steam" both work)
switch ($platformInput) {
    { $_ -imatch "steam" } {
        $imports = "Steam"
    }
    { $_ -imatch "epic" } {
        $imports = "EGS"
    }
    default {
        # Fallback in case they type something else
        Write-Warning "Unrecognized platform '$platformInput'. Defaulting to Steam."
        $imports = "Steam"
    }
}

if (Test-Path -Path $basedir -PathType Container) {
    
    # 7. Directory exists, try to set location (Set-Path is an alias for Set-Location)
    try {
        Set-Location -Path $basedir -ErrorAction Stop
        
        # 8. Confirm the location was set
        # We compare the string path of the current location ($PWD is a shortcut)
        if ($PWD.Path -eq $basedir) {
            Write-Host "Successfully changed directory to: $basedir" -ForegroundColor Green
        } else {
            # This might happen if the path was a symlink that resolved differently
            Write-Warning "Set-Location ran, but current path is now: $($PWD.Path)"
        }
    }
    catch {
        # This catches errors from Set-Location (e.g., permissions)
        Write-Error "Error: Failed to change directory to '$basedir'. You may not have permissions."
        Write-Error $_.Exception.Message
        throw $_
        # You might want to stop the script here, e.g., using 'return' or 'exit'
    }
}
else {
    # Directory does not exist
    Write-Error "Error: The directory '$basedir' does not exist."
    throw $_
    # You might want to stop the script here, e.g., using 'return' or 'exit'
}

# --- CONFIGURATION ---
# Set the path to the parent directory containing all your target folders.
#$baseDir = "c:\git\idletest"
$ADDON_DIR = Join-Path -Path $baseDir -ChildPath "Idle-Champions\AddOns"
$EMMOTE_DIR = Join-Path -Path $baseDir -ChildPath "IC_Addons\IC_Addons"
$IMP_DIR = Join-Path -Path $baseDir -ChildPath "IC_Addons-1"
$IMPORT_STEAM_DIR = Join-Path -Path $baseDir -ChildPath "ic_scripting_imports\Latest_Steam\Imports"
$IMPORT_EGS_DIR = Join-Path -Path $baseDir -ChildPath "ic_scripting_imports\Latest_EGS\Imports"
$IMPORT_TARGET = Join-Path -Path $ADDON_DIR -ChildPath "IC_Core\MemoryRead\Imports"

# Define addon lists as PowerShell arrays
$EMMOTE_ADDONS = @(
    "IC_BrivGemFarm_HideDefaultProfile_Extra",
    "IC_CazrinBooksFarmer_Extra",
    "IC_ClaimDailyPlatinum_Extra",
    "IC_EGSOverlaySwatter_Extra",
    "IC_GameSettingsFix_Extra",
    "IC_HybridTurboStacking_PreferredEnemies_Extra",
    "IC_NoModronAdventuring_Extra"
)

$IMP_ADDONS = @(
    "IC_BrivGemFarm_BrivFeatSwap_Extra",
    "IC_BrivGemFarm_LevelUp_Extra",
    "IC_RNGWaitingRoom_Extra",
    "IC_AreaTiming_Extra",
    "IC_BrivGemFarm_HybridTurboStacking_Extra",
    "IC_ProcessAffinity_Extra"
)

# --- HELPER FUNCTION: CREATE JUNCTION ---
# This function creates a directory junction (a type of symbolic link).
# It will remove any existing file or directory at the target path first.
function Create-Junction {
    param(
        [string]$LinkPath,
        [string]$SourcePath
    )

    try {
        # 1. Check for and remove any existing item at the target path
        if (Test-Path -Path $LinkPath -PathType Any) {
            Remove-Item -Path $LinkPath -Recurse -Force -ErrorAction Stop
        }

        # 2. Create the new junction using the native PowerShell cmdlet
        New-Item -ItemType Junction -Path $LinkPath -Value $SourcePath -ErrorAction Stop | Out-Null
        
        # Return $true to indicate success
        return $true
    }
    catch {
        Write-Warning "Failed to create junction from '$SourcePath' to '$LinkPath'."
        # Return $false to indicate failure
        return $false
    }
}

# --- SCRIPT EXECUTION ---

# 1. Define the prompt's title and message
#$title = "Select Platform"
#$message = "Which platform do you use for Idle Champions?"

# 2. Define the choices the user can pick from
##$steamChoice = New-Object System.Management.Automation.Host.ChoiceDescription "&Steam", "Selects the Steam platform."
#$epicChoice = New-Object System.Management.Automation.Host.ChoiceDescription "&Epic", "Selects the Epic Games Store (EGS) platform."

# Create an array of the choices
#$choices = [System.Management.Automation.Host.ChoiceDescription[]]($steamChoice, $epicChoice)

# 3. Show the prompt to the user
# (The '0' means Steam is the default choice)
#$selectionIndex = $host.UI.PromptForChoice($title, $message, $choices, 0)

# 4. Set the '$imports' variable based on their selection
#switch ($selectionIndex) {
#    0 { $imports = "Steam" }  # User selected the first choice (Steam)
#    1 { $imports = "EGS" }    # User selected the second choice (Epic)
#}

Set-Location -Path $baseDir
Write-Host "Cloning from github"
git clone --quiet https://github.com/mikebaldi/Idle-Champions
git clone --quiet https://github.com/Emmotes/IC_Addons/
git clone --quiet -b Anti-Changes https://github.com/antilectual/IC_Addons-1.git
git clone --quiet https://github.com/Emmotes/ic_scripting_imports




Write-Host "Starting addon linking process..."
Write-Host "Target AddOn Directory: $ADDON_DIR"

# Check if the base directory exists
if (-not (Test-Path -Path $baseDir -PathType Container)) {
    Write-Host "❌ Error: baseDir not found: $baseDir" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
### Linking EMMOTE Addons

Write-Host ""
Write-Host "--- Linking EMMOTE Addons (Source: $EMMOTE_DIR) ---"

foreach ($addon in $EMMOTE_ADDONS) {
    $SourcePath = Join-Path -Path $EMMOTE_DIR -ChildPath $addon
    $LinkPath = Join-Path -Path $ADDON_DIR -ChildPath $addon

    # Check if the source directory exists before linking
    if (Test-Path -Path $SourcePath -PathType Container) {
        if (Create-Junction -LinkPath $LinkPath -SourcePath $SourcePath) {
            Write-Host "  ✅ Linked (Junction): $addon" -ForegroundColor Green
        }
    }
    else {
        Write-Host "  ⚠️ WARNING: Source directory not found for EMMOTE addon: $SourcePath" -ForegroundColor Yellow
    }
}


### Linking IMP Addons

Write-Host ""
Write-Host "--- Linking IMP Addons (Source: $IMP_DIR) ---"

foreach ($addon in $IMP_ADDONS) {
    $SourcePath = Join-Path -Path $IMP_DIR -ChildPath $addon
    $LinkPath = Join-Path -Path $ADDON_DIR -ChildPath $addon

    # Check if the source directory exists before linking
    if (Test-Path -Path $SourcePath -PathType Container) {
        if (Create-Junction -LinkPath $LinkPath -SourcePath $SourcePath) {
            Write-Host "Linked (Junction): $addon" -ForegroundColor Green
        }
    }
    else {
        Write-Host "WARNING: Source directory not found for IMP addon: $SourcePath" -ForegroundColor Yellow
    }
}

### Linking Imports

Write-Host ""
Write-Host "--- Linking Imports (Source: $IMPORT_STEAM_DIR) ---"

# Handle the existing directory by renaming it
if (Test-Path -Path $IMPORT_TARGET -PathType Container) {
    $oldImportPath = "$($IMPORT_TARGET).old"
    Write-Host "Moving existing Imports directory to: $oldImportPath"
    # Ensure the .old path doesn't already exist
    if (Test-Path -Path $oldImportPath) {
        Remove-Item -Path $oldImportPath -Recurse -Force
    }
    Rename-Item -Path $IMPORT_TARGET -NewName "Imports.old"
}
if($imports -eq "EGS"){
    $IMPORT_DIR = $IMPORT_EGS_DIR
}   
else {
    $IMPORT_DIR = $IMPORT_STEAM_DIR
}

# Create the junction for the Imports folder
if (Test-Path -Path $IMPORT_DIR -PathType Container) {
    if (Create-Junction -LinkPath $IMPORT_TARGET -SourcePath $IMPORT_DIR) {
        Write-Host "Linked (Junction): Imports" -ForegroundColor Green
    }
    else {
        Write-Host "Failed to link Imports." -ForegroundColor Red
    }
}
else {
    Write-Host "WARNING: Source directory not found for Imports: $IMPORT_DIR" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Addon link creation complete."
Read-Host "Press Enter to exit"
