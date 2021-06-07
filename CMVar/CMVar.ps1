Write-Log -Severity 1 -Message "Loading extension CMVar"
function LoadCSCode {
    $Code = @"
using System;
using System.Collections.Generic;
using System.Management;
using System.Runtime.InteropServices;
using System.Text;

namespace ConfigMgr
{
    public class CCMCollectionVariables
    {
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct DATA_BLOB
        {
            public int cbData;
            public System.IntPtr pbData;
        }

        [DllImport("Crypt32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool CryptUnprotectData(
            ref DATA_BLOB pDataIn,
            String szDataDescr,
            ref int pOptionalEntropy,
            IntPtr pvReserved,
            ref int pPromptStruct,
            int dwFlags,
            ref DATA_BLOB pDataOut
        );

        private static string GetProtectedValue(string name) {
            string retValue = string.Empty;
            using (var searcher = new ManagementObjectSearcher(@"root\ccm\Policy\Machine\ActualConfig", String.Format("SELECT * FROM CCM_CollectionVariable WHERE Name = \"{0}\"", name),new EnumerationOptions() { Timeout = new TimeSpan(0,0,15)})) {
                foreach (ManagementObject v in searcher.Get())
                {
                    using (var value = v) {

                        retValue = value["value"].ToString();
                    }
                }
            }
            System.GC.Collect();
            return retValue;
        }

        public static string Get(string name)
        { 
            var protectedValue = GetProtectedValue(name);
            if (string.IsNullOrEmpty(protectedValue))
            {
                return null;
            }
            var value = Unprotect(protectedValue);
            return value;
        }

        private static string Unprotect(string strData)
        {
            // Remove <PolicySecret Version="1"><![CDATA[xxxxxxxx (43 chars) in beginning and 
            // ]]></PolicySecret> (18 chars) at end (xxx... is first 4 bytes)
            strData = strData.Substring(43, strData.Length - (43 + 18));

            // Chop string up into bytes (first 4 bytes already dropped
            var byteData = new Byte[strData.Length / 2];
            for (var i = 0; i < (strData.Length / 2); i++)
            {
                byteData[i] = Convert.ToByte(strData.Substring(i * 2, 2), 16);
            }

            // Create a Blob to contain the encrypted bytes
            var cipherTextBlob = new DATA_BLOB();
            cipherTextBlob.cbData = byteData.Length;
            cipherTextBlob.pbData = Marshal.AllocCoTaskMem(cipherTextBlob.cbData);

            // Copy data from original source to the BLOB structure
            Marshal.Copy(byteData, 0, cipherTextBlob.pbData, cipherTextBlob.cbData);

            // Create a Blob to contain the unencrypted bytes
            var plainTextBlob = new DATA_BLOB();

            var dummy = 0;
            var dummy2 = 0;
            //Decrypt the Blob with the encrypted bytes in it, and store in the plain text Blob
            // if ([PKI.Crypt32]::CryptUnprotectData([ref]$cipherTextBlob, $null, [ref][IntPtr]::Zero, [IntPtr]::Zero, [ref][IntPtr]::Zero, 1, [ref]$plainTextBlob))

            if (CryptUnprotectData(ref cipherTextBlob, null, ref dummy, IntPtr.Zero, ref dummy2, 1, ref plainTextBlob))
            {
                // If the decryption was sucessful, create a new byte array to contain
                // plainTextBlob ends with \0 so string should be two bytes shorter (one 16 bit character)
                var bytePlainText = new byte[plainTextBlob.cbData - 2];

                // Copy data from the plain text Blob to the new byte array
                Marshal.Copy(plainTextBlob.pbData, bytePlainText, 0, bytePlainText.Length);

                // Convert the unicode byte array to plain text string and return it
                return new UnicodeEncoding().GetString(bytePlainText);
            }
            else
            {
                return null;
            }

        }
    }
}
"@

    try {
        Add-Type -TypeDefinition $Code -ReferencedAssemblies 'System.Management'
    } catch {
        $false
    }
}
function Get-CCMExecInstalled {
    if ((Get-Service -ErrorAction Ignore -Name CCMExec)) {
        try {
            Get-CimClass -ErrorAction Ignore -Namespace root\ccm\Policy\Machine\ActualConfig -ClassName CCM_CollectionVariable | Out-Null
            return $true
        } catch {
            Write-Log -Severity 3 -Message "Failed to find class CCM_CollectionVariable"
            return $false
        }
    }
    else {
        Write-Log -Severity 3 -Message "CCMExec service is not installed"
        return $false
    }
}
function Get-CMCollectionVariable {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $CMVariableName
    )
    try {
        if ($Script:IsCCMExecInstalled)  {
            LoadCSCode
            Write-Log -Severity 1 -Message "Returning value for variable '$CMVariableName'"
            return [ConfigMgr.CCMCollectionVariables]::Get($CMVariableName)
        }
        else {
            Write-Log -Severity 1 -Message "CCMExec was not detected, can not get value for variable."
            return $null
        }
    } catch {
        throw "Could not process code."
    }

}

$Script:IsCCMExecInstalled = Get-CCMExecInstalled
Write-Log -Severity 1 -Message "CCMExec is installed: $($Script:IsCCMExecInstalled)"
