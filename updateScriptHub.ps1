# Set the title for the PowerShell window
$Host.UI.RawUI.WindowTitle = "Addon Updater Script"

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
        
        Write-Host "  ✅ Linked (Junction): $(Split-Path $LinkPath -Leaf) -> $SourcePath" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Warning "Failed to create junction from '$SourcePath' to '$LinkPath'."
        return $false
    }
}

# --- SCRIPT EXECUTION ---

# 1. Get the directory from the user and store it in $baseDir
$baseDir = Read-Host -Prompt "Please enter the base directory where Scrupthub is installed"

# 2. Check if the base directory exists and CD into it
if (Test-Path -Path $baseDir -PathType Container) {
    try {
        Set-Location -Path $baseDir -ErrorAction Stop
        Write-Host "Successfully changed directory to: $baseDir" -ForegroundColor Green
    }
    catch {
        Write-Error "Error: Failed to change directory to '$baseDir'. You may not have permissions."
        throw "Failed to set location. Stopping script."
    }
}
else {
    # Directory does not exist
    throw "Error: The directory '$baseDir' does not exist. Stopping script."
}

# 3. Define all repository and import paths
$repoIdleChampions = Join-Path -Path $baseDir -ChildPath "Idle-Champions"
$repoEmmotes = Join-Path -Path $baseDir -ChildPath "IC_Addons"
$repoImp = Join-Path -Path $baseDir -ChildPath "IC_Addons-1"
$repoScriptingImports = Join-Path -Path $baseDir -ChildPath "ic_scripting_imports"

$IMPORT_TARGET = Join-Path -Path $repoIdleChampions -ChildPath "AddOns\IC_Core\MemoryRead\Imports"
$IMPORT_STEAM_DIR = Join-Path -Path $repoScriptingImports -ChildPath "Latest_Steam\Imports"
$IMPORT_EGS_DIR = Join-Path -Path $repoScriptingImports -ChildPath "Latest_EGS\Imports"

$allRepos = @(
    $repoIdleChampions,
    $repoEmmotes,
    $repoImp,
    $repoScriptingImports
)

# 4. Read the current 'Imports' junction to detect the platform
Write-Host "---"
Write-Host "Checking current 'Imports' junction..."
$currentPlatform = "Steam" # Default to Steam
try {
    # Get the junction target
    $currentTarget = (Get-Item $IMPORT_TARGET -ErrorAction Stop).Target
    
    if ($currentTarget -like "*Latest_EGS*") {
        $currentPlatform = "EGS"
        Write-Host "Detected platform: EGS"
    }
    else {
        Write-Host "Detected platform: Steam"
    }
}
catch {
    Write-Warning "Could not read existing 'Imports' junction. Defaulting to '$currentPlatform'."
}

# 5. Check if 'Imports' junction will be modified by the pull
Write-Host "---"
Write-Host "Checking for incoming changes in 'Idle-Champions' repo..."
try {
    Set-Location $repoIdleChampions
    
    # Fetch updates from remote but don't apply them yet
    #git fetch 2>&1
    
    # Check the log for files that are on the remote but not local (i.e., what 'pull' will bring in)
    #$pathInGit = "AddOns/IC_Core/MemoryRead/Imports"
    #$incomingFiles = git log HEAD..@{u} --name-only --pretty=format:"" 2>&1
    #$incomingFiles = git log 'HEAD..@{u}' --name-only --pretty=format:"" 2>&1
    #if ($incomingFiles -contains $pathInGit -Or $true) {
        #Write-Host "Change to '$pathInGit' detected in incoming pull." -ForegroundColor Yellow
        Write-Host "Removing junction *before* pull..."
        if (Test-Path -Path $IMPORT_TARGET) {

            # Get the item's properties
            # We use -Force to ensure we can see hidden or system attributes
             $item = Get-Item -Path $IMPORT_TARGET -Force

            # Check if the item has the "ReparsePoint" attribute (which junctions/symlinks have)
            $isJunction = $item.Attributes -band [System.IO.FileAttributes]::ReparsePoint

            if ($isJunction) {
            # --- IT IS A JUNCTION ---
            # Remove *only* the junction itself.
            # The key is to OMIT -Recurse.
            Write-Host "Removing junction: $IMPORT_TARGET"
            
            $item.Delete()
            } else {
                # --- IT IS A REGULAR DIRECTORY ---
                # Use your original command to remove the directory and all its contents.
                Write-Host "Removing directory and contents: $IMPORT_TARGET"
                Remove-Item -Path $IMPORT_TARGET -Recurse -Force
            }   
        } else {
            Write-Host "Path not found: $IMPORT_TARGET"
        }
    #}
    #else {
    #    Write-Host "No changes to '$pathInGit' detected in incoming pull. Leaving junction as-is."
    #}
}
catch {
    Write-Warning "Could not check for incoming git changes for '$repoIdleChampions'."
    Write-Warning $_.Exception.Message
}

# 6. Run 'git pull' on all 4 repositories
Write-Host "---"
Write-Host "Starting updates for all repositories..."

foreach ($repoPath in $allRepos) {
    $repoName = Split-Path $repoPath -Leaf
    Write-Host "--- Pulling updates for '$repoName' ---"
    
    if (-not (Test-Path $repoPath)) {
        Write-Warning "Directory not found: $repoPath. Skipping."
        continue
    }

    try {
        Set-Location $repoPath -ErrorAction Stop
        
        # Run git pull and redirect stderr (2) to stdout (1)
        # This prevents normal progress messages from appearing as red errors
        git pull 2>&1
    }
    catch {
        Write-Error "Failed to update repo: $repoName"
        Write-Error $_.Exception.Message
    }
}

# 7. Re-link the 'Imports' junction
Write-Host "---"
Write-Host "Updating 'Imports' junction for $currentPlatform platform..."

$linkSource = $IMPORT_STEAM_DIR
if ($currentPlatform -eq "EGS") {
    $linkSource = $IMPORT_EGS_DIR
}

if (Test-Path -Path $linkSource -PathType Container) {
    # This function will automatically remove any existing file/folder at the target
    Create-Junction -LinkPath $IMPORT_TARGET -SourcePath $linkSource
}
else {
    Write-Error "Source directory not found for Imports: $linkSource"
}

Write-Host "---"
Write-Host "Addon update process complete."
Read-Host "Press Enter to exit"