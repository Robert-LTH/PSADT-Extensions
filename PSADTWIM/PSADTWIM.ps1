Write-Log -Source 'PSADTWIM' "Start of PSADTWIM"

<#
    Not sure why but if Toolkit is loaded with Import-Module $dirFiles and $dirSupportFiles points to .\AppDeployToolkit\Files and .\AppDeployToolkit\SupportFiles
    If you run Deploy-Application.ps1 with no actions, it points to the right folder
#>
$Global:PSADTBasePath = Split-Path -Path $PSScriptRoot -Parent
$Global:PSADTWIMSupportFiles = Join-Path -Path $PSADTBasePath -ChildPath "SupportFiles"
$Global:PSADTWIMFiles = Join-Path -Path $PSADTBasePath -ChildPath "Files"
$Global:WIMFileName = "media.wim"
$Global:WIMPath = Join-Path -Path $PSADTWIMSupportFiles -ChildPath $WIMFileName

# Module is disabled by default
$Global:PSADTWIMEnabled = $false

function Global:New-WIM {
    param(
        [ValidateSet("Max","Fast","None")]
        [string]$CompressionType = "Max",
        [string]$Description = $installName,
        [string]$Name = $installName
    )
    # If the file already exist, do not overwrite
    if (-not (Test-Path -Path $WIMPath)) {
        $Params = @{
            LogPath = "$configToolkitLogDir\$installName-PSADTWIM-New-WindowsImage.log"
            Description = $Description
            Name = $Name
            CompressionType = $CompressionType
            ImagePath = $WIMPath
            CapturePath = $PSADTWIMFiles
        }
        # Create a WIM with the files present in the Files folder
        New-WindowsImage @Params
        # Since there is a WIM-file now, we need to enable this module. If not, Mount-WIM will not work.
        $Global:PSADTWIMEnabled = $true
    }
    else {
        throw "File already exist: '$WIMPath'"
    }
}
function Global:Unmount-WIM {
    param (
        [switch]$Save
    )
    if (-not $Global:PSADTWIMEnabled) {
        Write-Log -Source 'PSADTWIM-Unmount' "PSADTWIM is disabled"
        return
    }
    Write-Log -Source 'PSADTWIM-Unmount' "Dismount '$WIMPath'."
    try {
        
        $Params = @{
            ErrorAction = 'Stop'
            LogPath = "$configToolkitLogDir\$installName-PSADTWIM-Dismount-WindowsImage.log"
        }
        # Default if to discard changes.
        if ($Save.IsPresent) {
            $Params.Add('Save',$true)
        }
        else {
            $Params.Add('Discard',$true)
        }

        # Unmount
        Get-WindowsImage -Mounted -LogPath "$configToolkitLogDir\$installName-PSADTWIM-Get-WindowsImage.log" | 
            Where-Object { $_.ImagePath -eq $WIMPath } | 
                Dismount-WindowsImage @Params
    } catch {
        Write-Log -Source 'PSADTWIM-Unmount' -Message "Failed to dismount $($WIMPath): $_"
        Exit-Script -ExitCode 70101
    }
}
function Global:Mount-WIM {
    param(
        [switch]$Write
    )
    # If no file is found there is no need to process things
    if (-not $Global:PSADTWIMEnabled) {
        Write-Log -Source 'PSADTWIM-Unmount' "PSADTWIM is disabled"
        return
    }
    if ((Test-Path -Path $WIMPath)) {
        Write-Log -Source 'PSADTWIM-Mount' "Mount '$WIMPath'."
        # Check if image is already mounted
        $CurrentlyMounted = Get-WindowsImage -Mounted -LogPath "$configToolkitLogDir\$installName-PSADTWIM-Get-WindowsImage.log" | 
            Where-Object { $_.ImagePath -eq $WIMPath }
        if (-not $CurrentlyMounted) {
            # Check if destination directory is empty
            if ((Get-ChildItem -Path $PSADTWIMFiles).Count -gt 0) {
                Write-Log -Source "PSADTWIM-Mount" -Severity 3 -Message "Failed to mount wim, destination directory is not empty ($PSADTWIMFiles)"
                Exit-Script -ExitCode 70100
            }
            $MountParams = @{
                CheckIntegrity = $true
                Index = 1
                Path = $PSADTWIMFiles
                LogPath = "$configToolkitLogDir\$installName-PSADTWIM-Mount-WindowsImage.log"
            }
            # Default is to mount with ReadOnly because at runtime we usually only need to read.
            if (-not $Write.IsPresent) {
                $MountParams.Add('ReadOnly',$true)
            }
            Get-WindowsImage -ImagePath $WIMPath -LogPath "$configToolkitLogDir\$installName-PSADTWIM-Get-WindowsImage.log" | 
                Mount-WindowsImage @MountParams
        }
        else {
            Write-Log -Source 'PSADTWIM-Mount' "$WIMPath is already mounted"
        }
    }
    else {
        Write-Log -Source 'PSADTWIM-Mount' "$WIMPath does not exist."
    }
}

if (-not (Test-Path -ErrorAction SilentlyContinue -Path "$WIMPath")) {
    Write-Log -Source 'PSADTWIM' "A file with path '$WIMPath' was not found. PSADTWIM will not continue."
    return
}

if (-not $IsAdmin) {
    Write-Log -Severity 3 -Source 'PSADTWIM' "Executing user is not an administrator, can't process wim commands!"
    return
}

if (-not (Get-Command -ErrorAction SilentlyContinue -Name 'Mount-WindowsImage')) {
    Write-Log -Severity 3 -Source 'PSADTWIM' "Command 'Mount-WindowsImage' was not found, can't process wim commands!"
    Exit-Script
}
# Passed the checks, time to enable
$Global:PSADTWIMEnabled = $true

Mount-WIM

Write-Log -Source 'PSADTWIM' "End of PSADTWIM"