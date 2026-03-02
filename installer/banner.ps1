[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$e = [char]27
$bc = "$e[96m"; $c = "$e[36m"; $bm = "$e[95m"; $m = "$e[35m"
$w = "$e[97m"; $dk = "$e[90m"; $n = "$e[0m"

Write-Host ""
Write-Host "$dk  ──────────────────────────────────────────────────────────$n"
Write-Host ""
Write-Host "$bc    ██████╗ ██╗███████╗██╗  ██╗██████╗  ██████╗ ████████╗$n"
Write-Host "$c    ██╔══██╗██║██╔════╝██║ ██╔╝██╔══██╗██╔═══██╗╚══██╔══╝$n"
Write-Host "$bm    ██║  ██║██║███████╗█████╔╝ ██████╔╝██║   ██║   ██║   $n"
Write-Host "$m    ██║  ██║██║╚════██║██╔═██╗ ██╔══██╗██║   ██║   ██║   $n"
Write-Host "$bc    ██████╔╝██║███████║██║  ██╗██║  ██║╚██████╔╝   ██║   $n"
Write-Host "$c    ╚═════╝ ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝    ╚═╝   $n"
Write-Host ""
Write-Host "$w                      s t u d i o///diskrot $n"
Write-Host ""
Write-Host "$dk  ──────────────────────────────────────────────────────────$n"
Write-Host "$dk       diskrot.com · 2026$n"
Write-Host "$dk  ──────────────────────────────────────────────────────────$n"
Write-Host ""

$h = [char]0x2593
Write-Host -NoNewline "  "
1..50 | ForEach-Object {
    Write-Host -NoNewline -ForegroundColor DarkGray $h
    Start-Sleep -Milliseconds 12
}
Write-Host ""
