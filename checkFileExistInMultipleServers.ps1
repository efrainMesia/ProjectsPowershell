param([string]$p1= $null)
$serversFile = import-csv -path $p1
$serversFile.Host|ForEach-Object{
    $server = $_
    $file = "filePATH"
    if(Test-Path $file)
    {
        #in this case we used Split and we separte the sentece by ' ', you can also use Select-String
        Get-Content $file | %{$_.Split(' ')[1]} | Select-Object @{n='fileExist';e={"$_"}},@{n='Host';e={"$server"}}
    }                                                                                                          
    else{
        #If we dont find the file we are looking for. It creates a row that says File Not Found
        ''|select-Object @{n='fileExist';e={"File Not Found"}},@{n='Host';e={"$server"}}
    }
}