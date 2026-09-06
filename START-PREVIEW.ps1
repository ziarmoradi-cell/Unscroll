$ErrorActionPreference = 'Stop'
$taskNode = Get-Command node -ErrorAction SilentlyContinue
if (-not $taskNode) { throw 'Node.js wird benötigt, um die lokale Vorschau zu starten.' }
Write-Host 'Unscroll-Vorschau: http://127.0.0.1:4173'
Write-Host 'Dieses Fenster offen lassen. Beenden mit Strg+C.'
& $taskNode.Source (Join-Path $PSScriptRoot 'preview/server.cjs')
