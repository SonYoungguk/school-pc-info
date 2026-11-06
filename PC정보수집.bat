@echo off
rem PC info collector - double-click to run. Needs nothing installed (uses built-in Windows PowerShell).
set "SELF=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "$s=[IO.File]::ReadAllText($env:SELF,[Text.Encoding]::UTF8); $i=$s.IndexOf('#'+'PSBEGIN'); iex $s.Substring($i)"
exit /b
#PSBEGIN
Add-Type -AssemblyName Microsoft.VisualBasic
Add-Type -AssemblyName System.Windows.Forms

$title = 'PC 정보 수집'
function Show-Msg([string]$text, [string]$icon) {
    [void][System.Windows.Forms.MessageBox]::Show($text, $title, 'OK', $icon)
}

try {
    $name = ([Microsoft.VisualBasic.Interaction]::InputBox('선생님의 성함을 입력해주세요.', $title, '')).Trim()
    if (-not $name) {
        Show-Msg "성함이 입력되지 않아 종료합니다.`n다시 실행해주세요." 'Information'
        exit
    }

    # 제조년월(추정): BIOS 출시일 기준
    $bios = Get-CimInstance Win32_BIOS | Select-Object -First 1
    $made = '확인 불가'
    if ($bios -and $bios.ReleaseDate) { $made = $bios.ReleaseDate.ToString('yyyy-MM') }

    # CPU
    $cpu = '확인 불가'
    $proc = Get-CimInstance Win32_Processor | Select-Object -First 1
    if ($proc -and $proc.Name) { $cpu = ($proc.Name -replace '\s+', ' ').Trim() }

    # RAM (GB)
    $ramBytes = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum
    if (-not $ramBytes) { $ramBytes = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory }
    $ram = [string][math]::Round($ramBytes / 1GB)

    # 유선 IP: 연결된 이더넷 어댑터의 IPv4 (무선/블루투스/가상 제외)
    $ips = @()
    try {
        $skip = 'Wi-?Fi|Wireless|802\.11|WLAN|Bluetooth|Virtual|VMware|VirtualBox|Hyper-V|TAP|VPN|Loopback'
        $adapters = Get-NetAdapter -Physical | Where-Object {
            $_.Status -eq 'Up' -and
            $_.PhysicalMediaType -notin @('Native 802.11', 'Wireless LAN', 'Wireless WAN', 'Bluetooth') -and
            $_.InterfaceDescription -notmatch $skip
        }
        foreach ($a in $adapters) {
            $found = Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Where-Object { $_.IPAddress -notlike '169.254.*' }
            foreach ($f in $found) { $ips += $f.IPAddress }
        }
    } catch { }
    $ip = '유선 연결 없음'
    if ($ips.Count -gt 0) { $ip = $ips -join ', ' }

    # 저장: 바탕화면\성함.txt (탭으로 구분된 헤더 1줄 + 데이터 1줄)
    $headers = '성함', '컴퓨터이름', '제조년월(추정)', 'CPU', 'RAM(GB)', '유선IP', '수집일시'
    $row = $name, $env:COMPUTERNAME, $made, $cpu, $ram, $ip, (Get-Date -Format 'yyyy-MM-dd HH:mm')
    $text = ($headers -join "`t") + "`r`n" + ($row -join "`t") + "`r`n"

    $safe = $name -replace '[\\/:*?"<>|]', '_'
    $desktop = [Environment]::GetFolderPath('Desktop')
    $path = Join-Path $desktop "$safe.txt"
    [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding($true)))

    $msg = "수집이 끝났습니다.`n`n" +
        "성함: $name`n" +
        "제조년월(추정): $made`n" +
        "CPU: $cpu`n" +
        "RAM: ${ram}GB`n" +
        "유선 IP: $ip`n`n" +
        "바탕화면에 '$safe.txt' 파일이 만들어졌습니다.`n이 파일을 전달해주세요."
    Show-Msg $msg 'Information'
} catch {
    Show-Msg ("오류가 발생했습니다. 아래 내용을 알려주세요.`n`n" + $_.Exception.Message) 'Error'
}
