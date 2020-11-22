$ComPorts_OK = Get-WmiObject Win32_SerialPort |Where-Object {$_.Status -like "*OK*"} | Select-Object deviceID
$ComPorts_notworking = Get-WmiObject Win32_SerialPort |Where-Object {$_.Status -like "*Fail*"} | Select-Object deviceID
$regedit_path = "HKCU:\SOFTWARE\SimonTatham\PuTTY\Sessions\"
$regedit_source = "HKCU:\SOFTWARE\SimonTatham\PuTTY\Sessions\Default%20Settings"

try {
    foreach ($port in $ComPorts_notworking)
    {
        $noworkingport = $regedit_path + $port
        Remove-Item -Path $noworkingport
    }
    
    if(-Not(Test-Path $regedit_source))
    {
        regedit.exe /C '.\default_settings.reg'
    }
    Foreach ( $port in $ComPorts_OK )
    {
        $registry = $regedit_path + $port.deviceID
        if(-Not (Test-Path $registry))
        {
            Write-Host "Setting the port: '$($port."deviceID")'"
            $registry = $regedit_path + $port.deviceID
            Copy-Item -Path $regedit_source -Destination $registry
            Set-ItemProperty -Path $registry -Name SerialLine -Value $port.deviceID
            Set-ItemProperty -Path $registry -Name SerialSpeed -Value 115200
        }
    }
}
catch{
    Write-Host "Something went wrong"
}