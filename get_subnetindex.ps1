#mandatory
param(
    [int]$maxrange=254,
    [int]$minrange=1
)

$if_index = (Get-NetIPInterface | Where-Object { $_.AddressFamily -eq "IPv4" -and $_.Dhcp -eq "Enabled" -and $_.ConnectionState -eq "Connected" }).ifIndex
$ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $if_index).IPAddress
$mac = (Get-NetAdapter -InterfaceIndex $if_index).MacAddress
Write-Host
Write-Host "Local ID"
Write-Host "Computername: $($env:COMPUTERNAME)"
Write-Host "IP: $ip"
Write-Host "Hostname: " (hostname)
Write-Host "Adapter-Mac: " $mac
Write-Host
#https://stackoverflow.com/questions/59909992/temporarily-change-powershell-language-to-english
# ([cultureinfo]::CurrentUICulture).Name "en-US" "de-DE"

function Wait-Jobs
{
    Param
    (
        [int] $sleepInterval
    )

    Process 
    {
        Write-Host
        While (Get-Job -State "Running") {
            Write-Host "Running jobs pending..."
            Get-Job | Out-Null
            Start-Sleep $sleepInterval 
        }
        Get-Job | Out-Null
        Write-Host
        Write-Host "All jobs completed. Grabbing output now"
    }
}

$ip_list = @()
$mac_list = @()
$host_list = @()

$results = @()

$subnet = $ip -replace $ip.Substring($ip.LastIndexOf(".") + 1),"?"

Write-Host "Subnet", $subnet, "($minrange-$maxrange)"
Write-Host

#credits https://sid-500.com/2017/12/09/powershell-find-out-whether-a-host-is-really-down-or-not-with-test-connectionlocalsubnet-ping-arp/
for($i=$minrange; $i -le $maxrange; $i++) {
    $query_ip = $($ip -replace $ip.Substring($ip.LastIndexOf(".") + 1), [string]$i)
    Write-Host "Start-Job: ping $query_ip"
    $ping = {(ping -n 1 -w 100 $using:query_ip 2>&1) | Out-Null; return [PSCustomObject]@{ IP = $using:query_ip; ResponseCode = $LASTEXITCODE}}
    Start-Job -ScriptBlock $ping | Out-Null
}
Wait-Jobs(3)
Get-Job | Receive-Job | ForEach-Object { 
    if($_.ResponseCode -eq 0) {
        $ip_list += $_.IP
    }
}
Write-Host "..."
Write-Host "Done. Removing jobs now"
Remove-Job *

foreach($address in $ip_list) {
    if($address -eq $ip) {
        $mac_address = $mac
    } else {
        $mac_address = (arp -a $address | Select-String '([0-9a-f]{2}-){5}[0-9a-f]{2}').Matches.Value
    }
    #https://stackoverflow.com/questions/41632656/getting-the-mac-address-by-arp-a
    #https://morgantechspace.com/2015/06/powershell-find-machine-name-from-ip-address.html
    $mac_list += $mac_address
    try {
        $host_name = [System.Net.Dns]::GetHostByAddress($address).Hostname
        $host_list += $host_name
    }
    catch [System.Net.Sockets.SocketException] {
        $host_list += "(no record data found)"
    }
    catch {
        $host_list += "Error: $_"
    }
}

for($j=0; $j -lt $ip_list.Count; $j++) {
    $results += [PSCustomObject]@{ ID = $j; IP = $ip_list[$j]; MAC = $mac_list[$j]; MACHINENAME = $host_list[$j] }
}

$filename = $subnet -replace "\?", "index.csv"

Write-Host
Write-Host "Printing results and exporting them to .\$filename"
Write-Host
$results | ForEach-Object { 
    Write-Host "ID", $_.ID, "IP", $_.IP, "MAC", $_.MAC, "HOSTNAME", $_.MACHINENAME
    $_
} | Export-Csv -Path $filename -Delimiter ';' -NoTypeInformation
#Delimiter excel win
#https://stackoverflow.com/questions/51299726/csv-file-output-from-powershell-is-displayed-in-one-column-in-excel
#https://stackoverflow.com/questions/14012773/difference-between-psobject-hashtable-and-pscustomobject
#https://stackoverflow.com/questions/65363870/export-hashtable-to-csv-from-keys-to-value
#https://stackoverflow.com/questions/10655788/powershell-set-content-and-out-file-what-is-the-difference
Invoke-Item -Path $filename
Write-Host
Write-Host "All operations done."
Write-Host
pause