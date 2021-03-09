function Read-DPInstExitCode {
    param(
        $DPInstExitCode
    )
    # http://msierrors.com/drivers/dpinst-exit-codes-explained/
    $DPInstExitCode = [Convert]::ToUInt32(("{0:X0}" -f $proc.ExitCode),16)

    $WW = ($DPInstExitCode -band 0xFF000000) -shr 24
    $XX = ($DPInstExitCode -band 0x00FF0000) -shr 16
    $YY = ($DPInstExitCode -band 0x0000FF00) -shr 8
    $ZZ = $DPInstExitCode -band 0x000000FF

    if ($WW -band 0x80) {
        if ($DeploymentType -eq 'Uninstall') {
            Write-Log -Severity 1 -Message "The following error could come from missing inf in the system."    
        }
        Write-Log -Severity 3 -Message "Failed to $DeploymentType a package."

        $Result = 71001
    }
    if ($WW -band 0x40) {
        Write-Log -Severity 1 -Message "DPinst indicates that a reboot is needed"
        $Result = 3010
    }
    if ($WW -ne 0 -and $WW -ne 0x40 -and $WW -ne 0x80) {
        Write-Log -Severity 1 -Message "This should never happen. WW is $WW"
        $Result = 71002
    }

    Write-Log -Severity 1 -Message "$XX number of packages could not be installed."
    Write-Log -Severity 1 -Message "$YY number of packages copied to driver store but was not installed."
    Write-Log -Severity 1 -Message "$ZZ number of packages installed on a device."

    if (($XX -eq 0) -and (($YY -gt 0) -or ($ZZ -gt 0)) -and $ExitCode -ne 3010) {
        Write-Log -Severity 1 -Message "Looks like success"
        $Result = 0
    }
    return $Result
}
function Global:Execute-DPInst {
    param(
        $PkgDir,
        $DPInstPath = "$dirSupportFiles\DPinst.exe",
        $HardError = $false
    )
    if (-not (Test-Path -Path $DPInstPath -ErrorAction SilentlyContinue)) {
        Write-Log -Severity 3 -Message "DPInst.exe was not found in '$DPInstPath'"
    }

    if ($deploymentType -ine 'Uninstall') {
        $Parameters = "/S /A /SA /SE /SW /PATH `"$PkgDir`" /F"
        $proc = Execute-Process -Path $DPInstPath -Parameters $Parameters -Passthru -IgnoreExitCodes *
        $Result = Read-DPInstExitCode $proc.ExitCode
    }
    else {
        Get-ChildItem -Path $PkgDir -Recurse -Filter '*.inf' | ForEach-Object {
            $Parameters = "/U `"$($_.FullName)`" /S /SE /SW /F"
            $proc = Execute-Process -Path $DPInstPath -Parameters $Parameters -Passthru -IgnoreExitCodes *
            $Result = Read-DPInstExitCode $proc.ExitCode
        }
        
    }
    if ($HardError -and $Result -ne 0) {
        Write-Log -Severity 1 -Message "Ending script because of HardError = true"
        Exit-Script -ExitCode $Result
    }
    else {
        Write-Log -Severity 1 -Message "Result: $Result"
        return $Result
    }
}

Write-Log "Loaded Execute-DPInst"
