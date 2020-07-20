function Get-LEDotNetVersion {
    <#
        .SYNOPSIS
        Gets current .NET Framework version

        .DESCRIPTION
        Gets current .NET version "numbers" from Microsofts official docs,
        then compares the clients registry .NET value.

        .EXAMPLE
        Get-LEdotNETversion
        Get-LEdotNETversion s204
        Get-LEdotNETversion PC-123ABC2

        .INPUTS
        Remote client

        .OUTPUTS
        string

        .NOTES
        Created on:     2020-03-20
        Created by:     Benjamin Nettervik
        Organization:   Nordlo Improve
        Filename:       Get-LEdotNETversion.ps1
        Requirements:   Powershell 4.0 (Active Directory)

        .LINK
        https://nordlo.com

        # TODO
        # [X] kolla .NET version på andra datorer / servrar
        # [X] kompabilitet med .NET v3.5
        # [X] kompabilitet med samtliga .NET versioner
    #>

    # TODO

    Param(
        [Parameter(Mandatory = $false)]
        [string]$remoteClient
    )

    function GetHTML {

        $statusCode = 0;

        while ($statusCode -ne 200) {
            $webresponse = Invoke-WebRequest "https://docs.microsoft.com/en-us/dotnet/framework/migration-guide/how-to-determine-which-versions-are-installed"
            $statusCode = $webresponse.StatusCode

            if ($statusCode -ne 200) {
                Write-Output "connection to Microsoft unsuccessfull, retrying... " -ForegroundColor Red
                Start-Sleep -s 2
            }
        }

        $htmlcode = $webresponse.RawContent

        $htmlCodeArray = $htmlcode.Split([Environment]::NewLine)

        $versionsTable = @()

        For ($i = 0; $i -le $htmlcodeArray.Length - 1; $i++) {
            if ($htmlCodeArray[$i].Contains("<td>.NET Framework")) {

                $version = $htmlCodeArray[$i]
                $versionNumber = $htmlCodeArray[$i + 1]

                $version = $version -replace '<td>.NET Framework ', ''
                $version = $version -replace '</td>', ''
                $version = $version -replace '\s', ''

                $versionNumber = $versionNumber -replace '<td>', ''
                $versionNumber = $versionNumber -replace '</td>', ''

                if ($versionNumber -notmatch '^[a-z]{2}[^a-z]' -and $versionNumber -notmatch 'All') {
                    $versionsTable += @{$version = $versionNumber}
                }
            }
        }

        $isRemoteClient = $false
        if($remoteClient.Length -gt 0){
            try{
                Resolve-DnsName $remoteClient -ErrorAction Stop | Out-Null
            }
            catch{
                Write-Warning ("Cannot resolve client/server")
                return
            }

            try{
                Test-Connection $remoteClient -Count 2 -ErrorAction stop | Out-Null
            }
            catch{
                Write-Warning ("Client/server unreachable")
                return
            }

            $isRemoteClient = $true
        }

        DetermineVersion4
        DetermineVersion3AndLower
    }

    function DetermineVersion4 {
        $currentVersion = GetRegValue -_keyPath "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\" -_value "Release"

        for ($i = $versionsTable.Count - 1; $i -ge 0; $i--) {
            #går tydligen inte att konvertera hashtablevalue till integer, string å andra sidan..
            if($currentVersion -ge ([int]($versionsTable[$i].Values | Out-String))){
               $outPut = ".NET Framework " + $versionsTable[$i].keys
               Write-Output ($outPut)
               break
             }
        }

        $currentVersion = GetRegValue -_keyPath "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v4\Client" -_value "Install"
        if($currentVersion -eq 1){
            Write-Output ".NET Framework 4.0 Client"
        }

        $currentVersion = GetRegValue -_keyPath "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v4\Full" -_value "Install"
        if($currentVersion -eq 1){
            Write-Output ".NET Framework 4.0 Full"
        }
    }

    #500iq kod
    function DetermineVersion3AndLower{
        $currentVersion = GetRegValue -_keyPath "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v3.5" -_value "Install"

        if($currentVersion -eq 1){
            Write-Output ".NET Framework 3.5"
        }
        else{
            $currentVersion = GetRegValue -_keyPath "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v3.0\Setup" -_value "InstallSuccess"
            if($currentVersion -eq 1){
                Write-Output "-NET Framework 3.0"
            }
            else{
                $currentVersion = GetRegValue -_keyPath "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v2.0.50727" -_value "Install"
                if($currentVersion -eq 1){
                    Write-Output ".NET Framework 2.0"
                }
                else{
                    $currentVersion = GetRegValue -_keyPath "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v1.1.4322" -_value "Install"
                    if($currentVersion -eq 1){
                        Write-Output ".NET Framework 1.1"
                    }
                    else{
                        $currentVersion = GetRegValue -_keyPath "HKLM:\Software\Microsoft\.NETFramework\Policy\v1.0\3705" -_value "Install"
                        if($currentVersion -eq 1){
                            Write-Output ".NET Framework 1.0"
                        }
                        else{
                            Write-Output "No .NET v3.5 or lower installed."
                        }
                    }
                }
            }
        }
    }

    function GetRegValue{

        Param(
        [string]$_keyPath,
        [string]$_value,
        [string]$_oldWindows
    )
        #powershell 4 och lägre har ej Get-ItemPropertyValue, kör därför Get-ItemProperty
        if ($isRemoteClient) {
            try {
                Invoke-Command -ComputerName $remoteClient -ScriptBlock {
                    $currentVersion = (Get-ItemProperty -Path $using:_keyPath -Name $using:_value).$using:_value
                    return $currentVersion
                } -ErrorAction Stop
            }
            catch {
                return $_.Exception

            }
        }
        else {
            try{
                $currentVersion = (Get-ItemProperty -Path $_keyPath -Name $_value -ErrorAction Stop).$_value
                return $currentVersion
            }
            catch{
                return $_.Exception
            }
        }
    }

    GetHTML
}