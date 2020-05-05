param(
    [Parameter(Mandatory = $true)]
    [String]$filePath
    )
$serversFile = import-csv -path $filePath
$output = @()
foreach ($line in $serversFile)
{
    $server = $line.Host
    $file = "\\$server\c$\Inventory\Packages\bla.txt"
    if(Test-Connection $server -Count 1 -Quiet:$true)
    {
        if(Test-Path $file)
        {
            $SVDate = Get-Content $file | %{$_.Split(' ')[1]}
            $SVDeployed = Get-Content $file | %{$_.Split(' ')[11]}
            $output += $line|select-Object *,@{n='Date_SystemVersion';e={"$SVDate"}},
                                             @{n='SystemVersionDeployed';e={"$SVDeployed"}} 
            #$line.Date_SystemVersion = $SVDate
            #$line.SystemVersionDeployed = $SVDeployed
        }
        else{
            $output += $line|select-Object *,@{n='Date_SystemVersion';e={"File not exist"}},
                                             @{n='SystemVersionDeployed';e={"Unknown"}}
        } 
    }
    else
    {
        $output += $line|select-Object *,@{n='Date_SystemVersion';e={"Unable to connect to host"}},
                                         @{n='SystemVersionDeployed';e={"Unable to connect to host"}}
    }
}

$output | Export-Csv -Path $filePath -NoTypeInformation