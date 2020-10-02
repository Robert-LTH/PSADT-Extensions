# PSADTWIM

If you have an installation which contains alot of files the distribution of the files can be hard on the infrastructure. This module was created to keep the amount of files to a minimum.

## How to add it to PSADT
1. Put PSADTWIM.ps1 in the folder AppDeployToolkit
2. Edit *AppDeployToolkitExtensions.ps1* and add <pre>. $ScriptRoot\PSADTWIM.ps1</pre> below <pre># &lt;Your custom functions go here&gt;</pre>
3. Edit *Deploy-Application.ps1* and add 
    <pre>$Params = @{
		ErrorAction = 'Stop'
		LogPath = "$configToolkitLogDir\PSADTWIM $AppName-Dismount-WindowsImage.log"
		Discard = $true
	}
	Get-WindowsImage -Mounted -LogPath "$configToolkitLogDir\PSADTWIM $AppName-Get-WindowsImage.log" | 
		Where-Object { $_.ImagePath -eq $WIMPath } | 
			Dismount-WindowsImage @Params
    </pre>
    before <pre>Exit-Script -ExitCode $mainExitCode</pre> in the last "catch" of the script. This is to prevent leaving mounted images.
    Also add <pre>Unmount-WIM</pre> below <pre>##*===============================================
	##* END SCRIPT BODY
	##*===============================================</pre>

Example of the last lines of Deploy-Application.ps1:
<pre>
    ##*===============================================
	##* END SCRIPT BODY
	##*===============================================

    Unmount-WIM

	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	$Params = @{
		ErrorAction = 'Stop'
		LogPath = "$configToolkitLogDir\PSADTWIM $AppName-Dismount-WindowsImage.log"
		Discard = $true
	}
	Get-WindowsImage -Mounted -LogPath "$configToolkitLogDir\PSADTWIM $AppName-Get-WindowsImage.log" | 
		Where-Object { $_.ImagePath -eq $WIMPath } | 
			Dismount-WindowsImage @Params
	Exit-Script -ExitCode $mainExitCode
}
</pre>

## How to use
1. Import the module <pre>
Set-Location -Path "Path of PSADT to use"
Import-Module .\AppDeployToolkit\AppDeployToolkitMain.ps1</pre>
2. Put the files that should go into the WIM, in the folder named Files.
3. Create the WIM. Default name is $installName, default Description is $installName, default Compression is max. Change the defaults by appending the parameter.<pre>
New-WIM
</pre>
4. The files are copied into the newly created WIM and should be removed from the Files folder.
5. Mount the file<pre>
Mount-WIM
</pre>
6. Add the commands needed for install and uninstall to *Deploy-Application.ps1*

## Logs
When running the commands to mount-, dismount- and get-windowsimage the logs goes to:
* $configToolkitLogDir\\$installName-PSADTWIM-Get-WindowsImage.log
* $configToolkitLogDir\\$installName-PSADTWIM-Mount-WindowsImage.log
* $configToolkitLogDir\\$installName-PSADTWIM-Dismount-WindowsImage.log

## Exitcodes
* 70100 - Failed to mount wim
* 70110 - Failed to dismount