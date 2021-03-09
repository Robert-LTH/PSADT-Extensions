The exitcode that DPInst produces contains information about how many drivers were installed and if the installation requires a reboot.
This simple script tries to read that information and write it to the log.

For this script to work dpinst.exe needs to be placed in SupportFiles or have its path specified, example:

Execute-DPInst -DPInstPath C:\somefolder\DPInst.exe -PkgDir C:\PathToFolder\With\Drivers


If Execute-DPInst runs during installation it installs all the drivers found in the specified PkgDir.
If it runs during uninstall it recurses PkgDir to find all the INF-files that should be uninstalled.
