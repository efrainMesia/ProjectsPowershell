#Written by Efrain Mesia
Param(
[Parameter(Mandatory=$false)]
[Switch]$opencom,
[Parameter(Mandatory=$False)]
[Switch]$clean,
[Parameter(Mandatory=$False)]
[Switch]$automation,
[Parameter(Mandatory=$False)]
[Switch]$closecom
)

$putty = "C:\Program Files\PuTTY\putty.exe"

function Print($ToPrint)
{
	$ToPrint | Format-Table -AutoSize 
	
}

#Get the profiles that start with COM and IP that ends with 5
function Get-ProfilesConfigured([Switch]$com,[Switch]$ip)
{    
	try{
		$regedit_path = "HKCU:\SOFTWARE\SimonTatham\PuTTY\Sessions\"
		#Check in registry if there is any folder with name COM1,COM2, etc
		$comConfigured = Get-ChildItem $regedit_path -ErrorAction Stop | Where-Object {($_.Name -match "COM*")} | select @{Name="Profiles_Configured";Expression={$_.PSChildName}}
		if($ip)
		{
			$comConfigured += Get-ChildItem $regedit_path -ErrorAction Stop | Where-Object {($_.Name -match "\d.\d.\d.5")} | select @{Name="Profiles_Configured";Expression={$_.PSChildName}}
		}
	}
	catch
	{
		Write-Error -Message "Unable to retrieve information from registry"
	}
    return $comConfigured
}


#Creating List of working comports
function Get-ConnectComs
{
	$comports_working = New-Object -TypeName "System.Collections.ArrayList"
	[System.Collections.ArrayList]@()
	Get-WmiObject -query "SELECT * FROM Win32_PnPEntity" | 
		ForEach-Object{
			if (($_.Name -match "COM\d+") -and ($_.Name -notlike "*Intel(R)*") -and ($_.Status -like "OK")) 
			{
				$comports_working+=$Matches[0]
			} 
		}
	return $comports_working
}



function Set-ProfilesPutty($Comports)
{
	$regedit_source = "HKCU:\SOFTWARE\SimonTatham\PuTTY\Sessions\Default%20Settings"
	$regedit_path = "HKCU:\SOFTWARE\SimonTatham\PuTTY\Sessions\"

	try{
		foreach ($port in $Comports)
		{
			$registry = $regedit_path + $port
			if(test-path $registry)
			{
				Write-Host "Deleting the profile: $registry"
				remove-item $registry
				continue
			}
			else
			{
				Copy-Item -Path $regedit_source -Destination $registry -ErrorAction Stop
			}
			if($port -like "192.168.137.5")
			{	
				Set-ItemProperty -Path $registry -Name HostName -Value ("root@"+$port)
				Set-ItemProperty -Path $registry -Name Protocol -Value "ssh"
				Set-ItemProperty -Path $registry -Name PortNumber -Value 22
				Write-Host "~~~Profile $port configured successfully"
			}
			else
			{
				Set-ItemProperty -Path $registry -Name SerialLine -Value $port  
				Set-ItemProperty -Path $registry -Name SerialSpeed -Value 115200
				if($automation)
				{
					New-Item $PWD\putty_log -ItemType Directory -ErrorAction SilentlyContinue
					Set-ItemProperty -Path $registry -Name LogFileName -Value "$PWD\putty_log\putty_&Y-&M-&D_&T.log"
				}
				Write-Host "~~~Profile $port configured successfully"
			}
		}
	}
	catch [System.Management.Automation.ActionPreferenceStopException]
	{
		Write-Error -Message "~~~Path $regedit_source was not found."
	}

}


function Open-ComPutty
{
	$Profiles_Putty = Get-ProfilesConfigured -com
    foreach($com in $Profiles_Putty)
	{
		$arguments = '-load ' + $com.Profiles_Configured
		Start-Process -FilePath $putty -ArgumentList $arguments
	}
}


function Remove-ProfilesPutty()
{
	$Profiles = Get-ProfilesConfigured -com -ip
	$regedit_path = "HKCU:\SOFTWARE\SimonTatham\PuTTY\Sessions\"
	Write-host "Cleaning all profiles in putty"
	foreach ($profile in $Profiles)
	{
		$registry = $regedit_path + $profile.Profiles_Configured
		Write-Host "$registry"
		if(test-path $registry)
		{
			Write-Host "Deleting the profile: $registry"
			remove-item $registry
		}
	}
}




##################### MAIN #############################

#1. Check if putty is opened
Write-Host "~~~Checking if putty is open..."
$putty_pid = Get-Process putty  -ErrorAction SilentlyContinue

#checking if 
if($putty_pid -or $closecom )
{
	write-host "~~~Putty is open. Putty will be restarted"
	Stop-Process $putty_pid
}
else{
	Write-Host "~~~Putty process wasnt found."
}


#2. Get all com ports.
Write-Host "~~~Getting Coms connected to the host..."
$comports_working = Get-ConnectComs



#adding SSH Connection
$comports_working +='192.168.137.5'
if($clean)
{
	Write-Host "~~~Clean flag was raised, cleaning all profiles and creating new ones"
	Remove-ProfilesPutty
}

#3. Get the profiles that start with COM and IP that ends with 5
$profiles_configured = Get-ProfilesConfigured -com -ip

Print($profiles_configured)



#4. Compare between profiles that are configured & profiles that are working
if($profiles_configured)
{
	$ComPorts_toconfigure = Compare-Object -ReferenceObject $comports_working -DifferenceObject  $profiles_configured.Profiles_Configured -PassThru 
	Write-Host "~~~Ports to configure:"
}
else #else 
{
	Write-Host "~~~None profile in putty was found. Whats about to be created: "
    $ComPorts_toconfigure = $comports_working
}

Print($ComPorts_toconfigure)

#5. create profiles in Putty's registry
if($ComPorts_toconfigure)
{
	write-host "~~~Creating Profiles....."
	Set-ProfilesPutty($ComPorts_toconfigure)
}


if($opencom)
{
	Open-ComPutty
}

if($putty_pid -and (-Not $closecom))
{
	Start-Process -FilePath $putty
}

