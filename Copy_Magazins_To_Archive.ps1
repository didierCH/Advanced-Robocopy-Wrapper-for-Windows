# Directory Migration Script with Ownership and Permission Management
# Requires Administrator privileges

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator. Please restart PowerShell as Administrator and try again."
    exit 1
}

# Function to get directory size
function Get-DirectorySize {
    param([string]$Path)
    try {
        $size = (Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        if ($null -eq $size) { $size = 0 }
        return $size
    }
    catch {
        Write-Warning "Could not calculate size for path: $Path. Error: $($_.Exception.Message)"
        return 0
    }
}

# Function to format file size
function Format-FileSize {
    param([long]$Size)
    $units = @("B", "KB", "MB", "GB", "TB")
    $index = 0
    $formattedSize = $Size
    while ($formattedSize -ge 1024 -and $index -lt $units.Length - 1) {
        $formattedSize = $formattedSize / 1024
        $index++
    }
    return "{0:N2} {1}" -f $formattedSize, $units[$index]
}

# Get source and destination paths
do {
    $sourcePath = Read-Host "Enter the source path"
    if (-not (Test-Path $sourcePath -PathType Container)) {
        Write-Host "Source path does not exist or is not a directory. Please try again." -ForegroundColor Red
    }
} while (-not (Test-Path $sourcePath -PathType Container))
do {
    $destinationPath = Read-Host "Enter the destination path"
    $destinationParent = Split-Path $destinationPath -Parent
    if (-not (Test-Path $destinationParent)) {
        Write-Host "Destination parent directory does not exist. Please try again." -ForegroundColor Red
    }
} while (-not (Test-Path $destinationParent))

# Ask the user about permission changes
do {
    $changePermissions = Read-Host "Would you like to change ownership and permissions? (y/n)"
    if ($changePermissions -notmatch '^[yn]$') {
        Write-Host "Invalid input. Please type 'y' for yes or 'n' for no." -ForegroundColor Red
    }
} while ($changePermissions -notmatch '^[yn]$')

# Create log file path
$logPath = Join-Path (Split-Path $destinationPath -Parent) "migration_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$robocopyLogPath = Join-Path (Split-Path $destinationPath -Parent) "robocopy_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

# Start logging
$logContent = @()
$logContent += "Directory Migration Script Log"
$logContent += "=============================="
$logContent += "Start Time: $(Get-Date)"
$logContent += "Source Path: $sourcePath"
$logContent += "Destination Path: $destinationPath"
$logContent += ""

Write-Host "Starting directory migration process..." -ForegroundColor Green

# Conditional block for ownership and permission changes
if ($changePermissions -eq 'y') {
    # Get the name of the administrator currently running the script
    $currentAdmin = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Host "Setting ownership of source directory to $currentAdmin..." -ForegroundColor Yellow
    $logContent += "Step 1: Setting ownership"

    try {
        # Take ownership of the directory and all subdirectories/files
        $takeownResult = & takeown /f "$sourcePath" /r /d y 2>&1

        # Set ownership to the current administrator
        $icalcResult = & icacls "$sourcePath" /setowner "$currentAdmin" /t /c 2>&1

        $logContent += "Ownership change completed successfully"
        Write-Host "Ownership change completed." -ForegroundColor Green
    }
    catch {
        $errorMsg = "Error setting ownership: $($_.Exception.Message)"
        $logContent += $errorMsg
        Write-Error $errorMsg
    }

    # Step 2: Replace permissions with inheritable permissions
    Write-Host "Replacing child object permissions with inheritable permissions..." -ForegroundColor Yellow
    $logContent += ""
    $logContent += "Step 2: Setting inheritable permissions"

    try {
        # Reset permissions to inherit from parent
        $icalcPermResult = & icacls "$sourcePath" /reset /t /c 2>&1

        $logContent += "Permissions reset completed successfully"
        Write-Host "Permissions reset completed." -ForegroundColor Green
    }
    catch {
        $errorMsg = "Error setting permissions: $($_.Exception.Message)"
        $logContent += $errorMsg
        Write-Error $errorMsg
    }
} else {
    Write-Host "Skipping ownership and permission changes as requested." -ForegroundColor Cyan
    $logContent += "Skipped ownership and permission changes."
}

# Step 3: Calculate source directory size before copy
Write-Host "Calculating source directory size..." -ForegroundColor Yellow
$sourceSize = Get-DirectorySize -Path $sourcePath
$sourceSizeFormatted = Format-FileSize -Size $sourceSize

$logContent += ""
$logContent += "Step 3: Pre-copy measurements"
$logContent += "Source directory size: $sourceSize bytes ($sourceSizeFormatted)"
Write-Host "Source directory size: $sourceSizeFormatted" -ForegroundColor Cyan

# Step 4: Execute Robocopy
Write-Host "Starting Robocopy operation..." -ForegroundColor Yellow
$logContent += ""
$logContent += "Step 4: Robocopy operation"
$logContent += "Robocopy command: robocopy `"$sourcePath`" `"$destinationPath`" /E /MIR /W:5 /R:3"

$robocopyStartTime = Get-Date

try {
    # Execute Robocopy with specified parameters and log output
    $robocopyResult = & robocopy "$sourcePath" "$destinationPath" /E /MIR /W:5 /R:3 /LOG:"$robocopyLogPath" /TEE
    $robocopyExitCode = $LASTEXITCODE

    $robocopyEndTime = Get-Date
    $robocopyDuration = $robocopyEndTime - $robocopyStartTime

    $logContent += "Robocopy start time: $robocopyStartTime"
    $logContent += "Robocopy end time: $robocopyEndTime"
    $logContent += "Robocopy duration: $($robocopyDuration.ToString())"
    $logContent += "Robocopy exit code: $robocopyExitCode"
    $logContent += "Robocopy log saved to: $robocopyLogPath"

    # Interpret Robocopy exit codes
    switch ($robocopyExitCode) {
        0 { $status = "No files were copied (no change)" }
        1 { $status = "Files were copied successfully" }
        2 { $status = "Extra files or directories were detected and removed" }
        3 { $status = "Files were copied and extra files were removed" }
        4 { $status = "Some mismatched files or directories were detected" }
        8 { $status = "Some files or directories could not be copied" }
        16 { $status = "Fatal error occurred" }
        default { $status = "Multiple conditions occurred (exit code: $robocopyExitCode)" }
    }

    $logContent += "Robocopy status: $status"
    Write-Host "Robocopy completed with status: $status" -ForegroundColor Green
}
catch {
    $errorMsg = "Error during Robocopy operation: $($_.Exception.Message)"
    $logContent += $errorMsg
    Write-Error $errorMsg
}

# Step 5: Compare directory sizes
Write-Host "Comparing directory sizes..." -ForegroundColor Yellow
$logContent += ""
$logContent += "Step 5: Post-copy size comparison"

# Calculate destination directory size
$destinationSize = Get-DirectorySize -Path $destinationPath
$destinationSizeFormatted = Format-FileSize -Size $destinationSize

$logContent += "Source directory size: $sourceSize bytes ($sourceSizeFormatted)"
$logContent += "Destination directory size: $destinationSize bytes ($destinationSizeFormatted)"

# Calculate size difference
$sizeDifference = $sourceSize - $destinationSize
$sizeDifferenceFormatted = Format-FileSize -Size ([Math]::Abs($sizeDifference))

if ($sizeDifference -eq 0) {
    $comparisonResult = "MATCH - Directory sizes are identical"
    $comparisonColor = "Green"
} elseif ($sizeDifference -gt 0) {
    $comparisonResult = "DIFFERENCE - Source is larger by $sizeDifferenceFormatted"
    $comparisonColor = "Yellow"
} else {
    $comparisonResult = "DIFFERENCE - Destination is larger by $sizeDifferenceFormatted"
    $comparisonColor = "Yellow"
}

$logContent += "Size comparison result: $comparisonResult"

Write-Host "`nSize Comparison Results:" -ForegroundColor Cyan
Write-Host "Source: $sourceSizeFormatted" -ForegroundColor White
Write-Host "Destination: $destinationSizeFormatted" -ForegroundColor White
Write-Host "Result: $comparisonResult" -ForegroundColor $comparisonColor

# Step 6: Compare file counts and list differences
Write-Host "Comparing file counts..." -ForegroundColor Yellow
$logContent += ""
$logContent += "Step 6: File count comparison"

# Get a list of all files in the source and destination directories, including hidden files
try {
    # Add the -Force parameter to include hidden files
    $sourceFiles = Get-ChildItem -Path $sourcePath -Recurse -File -ErrorAction SilentlyContinue -Force
    $destinationFiles = Get-ChildItem -Path $destinationPath -Recurse -File -ErrorAction SilentlyContinue -Force

    $sourceFileCount = $sourceFiles.Count
    $destinationFileCount = $destinationFiles.Count

    $logContent += "Source file count: $sourceFileCount"
    $logContent += "Destination file count: $destinationFileCount"

    # Compare the counts and provide a result
    if ($sourceFileCount -eq $destinationFileCount) {
        $countResult = "MATCH - File counts are identical"
        $countColor = "Green"
        $logContent += "File count comparison result: $countResult"
        Write-Host "`nFile Count Comparison Results:" -ForegroundColor Cyan
        Write-Host "Source: $sourceFileCount files" -ForegroundColor White
        Write-Host "Destination: $destinationFileCount files" -ForegroundColor White
        Write-Host "Result: $countResult" -ForegroundColor $countColor
    } else {
        $countDifference = [Math]::Abs($sourceFileCount - $destinationFileCount)
        $countResult = "DIFFERENCE - There is a difference of $countDifference files."
        $countColor = "Red"
        $logContent += "File count comparison result: $countResult"
        Write-Host "`nFile Count Comparison Results:" -ForegroundColor Cyan
        Write-Host "Source: $sourceFileCount files" -ForegroundColor White
        Write-Host "Destination: $destinationFileCount files" -ForegroundColor White
        Write-Host "Result: $countResult" -ForegroundColor $countColor

        # Get the relative paths for both file lists
        $sourceRelativePaths = $sourceFiles | ForEach-Object { $_.FullName.Substring($sourcePath.Length) }
        $destinationRelativePaths = $destinationFiles | ForEach-Object { $_.FullName.Substring($destinationPath.Length) }

        # Identify the differences using the relative paths
        $differences = Compare-Object -ReferenceObject $sourceRelativePaths -DifferenceObject $destinationRelativePaths

        if ($differences) {
            Write-Host "`nLegend for File Differences:" -ForegroundColor Cyan
            Write-Host "  <= : File exists in the source but not the destination (Missing File)" -ForegroundColor Gray
            Write-Host "  => : File exists in the destination but not the source (Extra File)" -ForegroundColor Gray
            Write-Host ""
            $logContent += ""
            $logContent += "The following file differences were found:"
            $logContent += "Legend: <= (Missing), => (Extra)"
            Write-Host "`nThe following file differences were found:" -ForegroundColor Red
            foreach ($diff in $differences) {
                # Format the output to include the side indicator and the file path
                $output = "$($diff.SideIndicator) $($diff.InputObject)"
                $logContent += " - $output"
                Write-Host " - $output" -ForegroundColor Red
            }
        }
    }

} catch {
    $errorMsg = "Error during file count comparison: $($_.Exception.Message)"
    $logContent += $errorMsg
    Write-Error $errorMsg
}

# Step 7: Finalize logging
$logContent += ""
$logContent += "Migration completed at: $(Get-Date)"
$logContent += "Main log file: $logPath"
$logContent += "Robocopy log file: $robocopyLogPath"

# Write log to disk
try {
    $logContent | Out-File -FilePath $logPath -Encoding UTF8
    Write-Host "`nLog files created:" -ForegroundColor Green
    Write-Host "Main log: $logPath" -ForegroundColor White
    Write-Host "Robocopy log: $robocopyLogPath" -ForegroundColor White
}
catch {
    Write-Error "Error writing log file: $($_.Exception.Message)"
}

Write-Host "`nMigration process completed!" -ForegroundColor Green