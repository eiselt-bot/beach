[CmdletBinding()]
param(
    [string]$ConfigPath = "$PSScriptRoot\chat-config.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Status {
    param(
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::DarkGray
    )

    $timestamp = Get-Date -Format 'HH:mm:ss'
    Write-Host "[$timestamp] $Message" -ForegroundColor $Color
}

function Load-Config {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        $default = [ordered]@{
            room = [ordered]@{
                multicastAddress = '239.10.10.10'
                port = 45454
                heartbeatSeconds = 10
            }
            admins = @(
                [ordered]@{
                    username = 'Admin1'
                    ip = '127.0.0.1'
                    title = 'Leitung'
                    titleColor = 'Yellow'
                }
            )
            bans = @()
        }
        ($default | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $Path -Encoding UTF8
        Write-Status "Neue Konfiguration wurde erstellt: $Path" ([ConsoleColor]::Yellow)
    }

    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Save-Config {
    param(
        [pscustomobject]$Config,
        [string]$Path
    )

    ($Config | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Is-Banned {
    param(
        [pscustomobject]$Config,
        [string]$Username,
        [string]$LocalIp
    )

    foreach ($ban in @($Config.bans)) {
        if (($ban.username -eq $Username) -or ($ban.ip -eq $LocalIp)) {
            return $true
        }
    }

    return $false
}

function New-Packet {
    param(
        [string]$Type,
        [string]$From,
        [string]$Message,
        [string]$SenderIp,
        [hashtable]$Data
    )

    return [ordered]@{
        type = $Type
        from = $From
        message = $Message
        senderIp = $SenderIp
        timestamp = (Get-Date).ToString('o')
        data = $Data
    }
}

$config = Load-Config -Path $ConfigPath
$multicastAddress = [System.Net.IPAddress]::Parse($config.room.multicastAddress)
$port = [int]$config.room.port
$heartbeatSeconds = [int]$config.room.heartbeatSeconds

$localIp = (
    Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike '169.254*' -and $_.IPAddress -ne '127.0.0.1' } |
    Select-Object -First 1 -ExpandProperty IPAddress
)
if (-not $localIp) {
    $localIp = '127.0.0.1'
}

$username = Read-Host 'Benutzername'
if ([string]::IsNullOrWhiteSpace($username)) {
    throw 'Benutzername darf nicht leer sein.'
}

if (Is-Banned -Config $config -Username $username -LocalIp $localIp) {
    Write-Status "Du bist gebannt (Nutzername/IP). Chat wird beendet." ([ConsoleColor]::Red)
    exit 1
}

$client = [System.Net.Sockets.UdpClient]::new($port)
$client.MulticastLoopback = $true
$client.JoinMulticastGroup($multicastAddress)
$remoteEndpoint = [System.Net.IPEndPoint]::new($multicastAddress, $port)

$peerTable = @{}
$script:chatClosed = $false
$script:bannedByCommand = $false

$adminsByIp = @{}
foreach ($admin in @($config.admins)) {
    $adminsByIp[$admin.ip] = $admin
}

function Send-Packet {
    param([hashtable]$Packet)

    $json = $Packet | ConvertTo-Json -Depth 6 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    [void]$client.Send($bytes, $bytes.Length, $remoteEndpoint)
}

function Get-DisplayName {
    param(
        [string]$Name,
        [string]$Ip
    )

    if ($adminsByIp.ContainsKey($Ip)) {
        $admin = $adminsByIp[$Ip]
        $title = $admin.title
        if (-not [string]::IsNullOrWhiteSpace($title)) {
            return "$Name [$title]"
        }
    }

    return $Name
}

function Write-ChatLine {
    param(
        [string]$Name,
        [string]$Ip,
        [string]$Text
    )

    $timestamp = Get-Date -Format 'HH:mm:ss'
    if ($adminsByIp.ContainsKey($Ip)) {
        $admin = $adminsByIp[$Ip]
        $colorName = if ($admin.titleColor) { $admin.titleColor } else { 'Yellow' }
        try {
            $color = [ConsoleColor]::$colorName
        } catch {
            $color = [ConsoleColor]::Yellow
        }
        Write-Host "[$timestamp] $(Get-DisplayName -Name $Name -Ip $Ip): $Text" -ForegroundColor $color
    } else {
        Write-Host "[$timestamp] $Name: $Text"
    }
}

function Handle-Command {
    param([pscustomobject]$Packet)

    $senderIp = [string]$Packet.senderIp
    if (-not $adminsByIp.ContainsKey($senderIp)) {
        return
    }

    $command = [string]$Packet.data.command
    $target = [string]$Packet.data.target
    $reason = [string]$Packet.data.reason

    if ($target -ne $username) {
        return
    }

    if ($command -eq 'kick') {
        Write-Status "Du wurdest von $($Packet.from) gekickt. Grund: $reason" ([ConsoleColor]::Red)
        $script:chatClosed = $true
        return
    }

    if ($command -eq 'ban') {
        Write-Status "Du wurdest von $($Packet.from) gebannt. Grund: $reason" ([ConsoleColor]::Red)

        $entry = [ordered]@{
            username = $username
            ip = $localIp
            by = $Packet.from
            reason = if ($reason) { $reason } else { 'ban command' }
            timestamp = (Get-Date).ToString('o')
        }

        $config.bans = @($config.bans) + $entry
        Save-Config -Config $config -Path $ConfigPath

        $script:bannedByCommand = $true
        $script:chatClosed = $true
        return
    }
}

Write-Status "UDP P2P Chat startet auf $($config.room.multicastAddress):$port" ([ConsoleColor]::Cyan)
Write-Status "Befehle: /help, /who, /kick <name> [grund], /ban <name> [grund], /title <text>, /quit" ([ConsoleColor]::DarkCyan)

Send-Packet -Packet (New-Packet -Type 'hello' -From $username -Message '' -SenderIp $localIp -Data @{})
$lastHeartbeat = Get-Date

try {
    while (-not $script:chatClosed) {
        while ($client.Available -gt 0) {
            $source = [System.Net.IPEndPoint]::new([System.Net.IPAddress]::Any, 0)
            $data = $client.Receive([ref]$source)
            $json = [System.Text.Encoding]::UTF8.GetString($data)

            try {
                $packet = $json | ConvertFrom-Json
            } catch {
                continue
            }

            if ([string]$packet.from -eq $username -and [string]$packet.senderIp -eq $localIp) {
                continue
            }

            $peerTable[[string]$packet.from] = [ordered]@{
                ip = [string]$packet.senderIp
                seen = Get-Date
            }

            switch ([string]$packet.type) {
                'chat' { Write-ChatLine -Name ([string]$packet.from) -Ip ([string]$packet.senderIp) -Text ([string]$packet.message) }
                'hello' { Write-Status "$(Get-DisplayName -Name ([string]$packet.from) -Ip ([string]$packet.senderIp)) ist beigetreten." ([ConsoleColor]::Green) }
                'heartbeat' { }
                'command' { Handle-Command -Packet $packet }
            }
        }

        if (((Get-Date) - $lastHeartbeat).TotalSeconds -ge $heartbeatSeconds) {
            Send-Packet -Packet (New-Packet -Type 'heartbeat' -From $username -Message '' -SenderIp $localIp -Data @{})
            $lastHeartbeat = Get-Date
        }

        $line = Read-Host "$username"
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        if ($line.StartsWith('/')) {
            $parts = $line.Split(' ', 3, [System.StringSplitOptions]::RemoveEmptyEntries)
            $cmd = $parts[0].ToLowerInvariant()

            switch ($cmd) {
                '/help' {
                    Write-Status '/who zeigt aktive Nutzer in der lokalen Tabelle.' ([ConsoleColor]::DarkCyan)
                    Write-Status '/kick <name> [grund] sendet Kick-Befehl (nur Admin-IP).' ([ConsoleColor]::DarkCyan)
                    Write-Status '/ban <name> [grund] zwingt Ziel, sich selbst in bans einzutragen.' ([ConsoleColor]::DarkCyan)
                    Write-Status '/title <text> sendet Systemtitel an alle.' ([ConsoleColor]::DarkCyan)
                    Write-Status '/quit beendet deinen Client.' ([ConsoleColor]::DarkCyan)
                }
                '/who' {
                    Write-Status 'Bekannte Teilnehmer:' ([ConsoleColor]::DarkGray)
                    foreach ($peer in $peerTable.GetEnumerator() | Sort-Object Name) {
                        Write-Status " - $($peer.Name) ($($peer.Value.ip))" ([ConsoleColor]::Gray)
                    }
                }
                '/kick' {
                    if (-not $adminsByIp.ContainsKey($localIp)) {
                        Write-Status 'Nur Administratoren dürfen /kick senden (IP muss in admins stehen).' ([ConsoleColor]::Red)
                        continue
                    }
                    if ($parts.Count -lt 2) {
                        Write-Status 'Syntax: /kick <name> [grund]' ([ConsoleColor]::Yellow)
                        continue
                    }
                    $target = $parts[1]
                    $reason = if ($parts.Count -ge 3) { $parts[2] } else { 'kein Grund angegeben' }
                    Send-Packet -Packet (New-Packet -Type 'command' -From $username -Message '' -SenderIp $localIp -Data @{ command = 'kick'; target = $target; reason = $reason })
                    Write-Status "Kick an $target gesendet." ([ConsoleColor]::Yellow)
                }
                '/ban' {
                    if (-not $adminsByIp.ContainsKey($localIp)) {
                        Write-Status 'Nur Administratoren dürfen /ban senden (IP muss in admins stehen).' ([ConsoleColor]::Red)
                        continue
                    }
                    if ($parts.Count -lt 2) {
                        Write-Status 'Syntax: /ban <name> [grund]' ([ConsoleColor]::Yellow)
                        continue
                    }
                    $target = $parts[1]
                    $reason = if ($parts.Count -ge 3) { $parts[2] } else { 'Verstoß gegen Regeln' }
                    Send-Packet -Packet (New-Packet -Type 'command' -From $username -Message '' -SenderIp $localIp -Data @{ command = 'ban'; target = $target; reason = $reason })
                    Write-Status "Ban an $target gesendet." ([ConsoleColor]::Yellow)
                }
                '/title' {
                    if ($parts.Count -lt 2) {
                        Write-Status 'Syntax: /title <text>' ([ConsoleColor]::Yellow)
                        continue
                    }
                    $msg = $line.Substring(7)
                    Send-Packet -Packet (New-Packet -Type 'chat' -From $username -Message "[TITEL] $msg" -SenderIp $localIp -Data @{})
                }
                '/quit' {
                    $script:chatClosed = $true
                }
                default {
                    Write-Status 'Unbekannter Befehl. /help für Hilfe.' ([ConsoleColor]::Yellow)
                }
            }
            continue
        }

        Send-Packet -Packet (New-Packet -Type 'chat' -From $username -Message $line -SenderIp $localIp -Data @{})
    }
}
finally {
    $client.DropMulticastGroup($multicastAddress)
    $client.Close()
}

if ($script:bannedByCommand) {
    exit 2
}

Write-Status 'Chat beendet.' ([ConsoleColor]::DarkGray)
