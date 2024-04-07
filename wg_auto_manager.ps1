Param(
    [Parameter(Position = 0, Mandatory=$True)]
    [string]
    $SSIDs,                                 # Whitelist of local SSIDs. Delimeter is |

    [Parameter(Position = 1, Mandatory=$True)]
    [string]
    $Config,                                # Absolute path to tunnel config file.

    [Parameter(Position = 2)]
    [string]                                # Why not Bool? https://github.com/MScholtes/PS2EXE?tab=readme-ov-file#parameter-processing
    $RegisterTask = "False"                 # Whether or not to register a task 
)

$tunnel_config = Get-ChildItem $config

# https://github.com/MScholtes/PS2EXE?tab=readme-ov-file#script-variables
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") { 
    $ScriptPath = $MyInvocation.PSCommandPath  
}
else { 
    $ScriptPath = [Environment]::GetCommandLineArgs()[0]
    if (!$ScriptPath){ 
        $ScriptPath = "."
    }
}

# Checks only for the desired connections. Otherwise, other interfaces like Tailscale will interefere.
$connections = (Get-NetConnectionProfile | Where-Object {$_.Name -match $SSIDs})
$tunnel      = (Get-Service ('WireGuardTunnel$' + $tunnel_config.BaseName) -ErrorAction SilentlyContinue)
$manager     = (Get-Service ('WireGuard Manager') -ErrorAction SilentlyContinue)

# Define the task name with a UUID to avoid conflicts
$taskName = "Wireguard_Auto_Management_Task_{d589d2d3-8d57-4e61-97c1-9981642f0014}"

# Define the XML content for the task
$taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
<RegistrationInfo>
    <Date>2024-01-01T00:00:01.000000</Date>
    <URI>\$taskName</URI>
</RegistrationInfo>
<Triggers>
    <EventTrigger>
    <Enabled>true</Enabled>
    <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"&gt;&lt;Select Path="Microsoft-Windows-NetworkProfile/Operational"&gt;*[System[Provider[@Name='Microsoft-Windows-NetworkProfile'] and EventID=10000]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
</Triggers>
<Principals>
    <Principal id="Author">
    <RunLevel>HighestAvailable</RunLevel>
    </Principal>
</Principals>
<Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
    <StopOnIdleEnd>true</StopOnIdleEnd>
    <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>true</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
    <Priority>7</Priority>
</Settings>
<Actions Context="Author">
    <Exec>
    <Command>$ScriptPath</Command>
    <Arguments>"$SSIDs" "$Config"</Arguments>
    </Exec>
</Actions>
</Task>
"@

if ($RegisterTask -Eq "True") {
    if ( !(Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue ) ) {
        Register-ScheduledTask -TaskName $taskName -Xml $taskXml -TaskPath \
        Write-Host "Task created successfully."
    } 
    else {
        Unregister-ScheduledTask -TaskName $taskName -TaskPath \
        Register-ScheduledTask -TaskName $taskName -Xml $taskXml -TaskPath \
        Write-Host "Task updated successfully."
    }
}
else {
    if ( (@($connections).Count -Gt 0) -and  ($tunnel)) {
        Write-Host "You are local:" $connections.Name
    
        wireguard.exe /uninstalltunnelservice $tunnel_config.BaseName
        Write-Host "Stopped:" $tunnel.DisplayName
    }
    if ( (@($connections).Count -Gt 0) -and !($tunnel)) {
        Write-Host "You are local:" $connections.Name
        Write-Host "Nothing to stop."
        Continue
    }
    if (!(@($connections).Count -Gt 0) -and  ($tunnel)) {
        Write-Host "You are NOT local:" (Get-NetConnectionProfile | Where-Object {$_.Name -notmatch $tunnel_config.BaseName}).Name
        Write-Host "Nothing to start. Running tunnel:" $tunnel.DisplayName
        Continue
    }
    if (!(@($connections).Count -Gt 0) -and !($tunnel)) {
        Write-Host "You are NOT local:" (Get-NetConnectionProfile | Where-Object {$_.Name -notmatch $tunnel_config.BaseName}).Name
    
        if(!($manager)) {
            wireguard.exe /installmanagerservice
            Write-Host "Started: WireGuard Manager"
        }
    
        wireguard.exe /installtunnelservice $tunnel_config
        Start-Sleep -Seconds 1
        Write-Host "Started:" (Get-Service ('WireGuardTunnel$' + $tunnel_config.BaseName) -ErrorAction SilentlyContinue).DisplayName
    }
}