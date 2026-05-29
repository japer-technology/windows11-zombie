<#
.SYNOPSIS
    Verify the SHA-256 hash chain in the windows-zombie audit log.

.DESCRIPTION
    Reads ``C:\ProgramData\AiZombie\logs\audit.log`` (or the file
    pointed to by ``$env:ZOMBIE_AUDIT_LOG``) and walks the
    ``prev_sha256`` field on each JSON line. Exits 0 when the chain
    is intact, 1 when tampering is detected, and 2 on argument or
    I/O errors.

    Lines that do not parse as JSON (for example, externally
    appended notes) are not validated and self-heal the chain at
    that boundary; they are reported as warnings.

.PARAMETER Path
    Override the audit log location. Defaults to
    ``$env:ZOMBIE_AUDIT_LOG`` or the install-root default.

.EXAMPLE
    PS> pwsh -File payload/bin/Verify-Audit.ps1
    [+] audit chain OK (1234 entries)

.EXAMPLE
    PS> pwsh -File payload/bin/Verify-Audit.ps1 -Path C:\backup\audit.log
#>
[CmdletBinding()]
param(
    [string]$Path
)

$ErrorActionPreference = 'Stop'

if (-not $Path -or $Path -eq '') {
    if ($env:ZOMBIE_AUDIT_LOG) {
        $Path = $env:ZOMBIE_AUDIT_LOG
    } else {
        $root = if ($env:AI_ZOMBIE_ROOT) { $env:AI_ZOMBIE_ROOT } else { Join-Path $env:ProgramData 'AiZombie' }
        $Path = Join-Path $root 'logs\audit.log'
    }
}

if (-not (Test-Path -LiteralPath $Path)) {
    Write-Host "[!] audit log missing: $Path" -ForegroundColor Yellow
    exit 0
}

# SHA-256 of the empty origin sentinel emitted by audit.py.
$expected = ('0' * 64)
$lineNo = 0
$entries = 0
$skipped = 0

try {
    $stream = [System.IO.File]::OpenRead($Path)
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.UTF8Encoding]::new($false))
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        while (-not $reader.EndOfStream) {
            $lineNo++
            $line = $reader.ReadLine()
            if (-not $line) { continue }
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($line)
            $hash = ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join ''
            try {
                $obj = $line | ConvertFrom-Json -ErrorAction Stop
            } catch {
                Write-Host "[!] line $lineNo is not JSON; chain self-heals here" -ForegroundColor Yellow
                $skipped++
                $expected = $hash
                continue
            }
            $actualPrev = $null
            if ($obj.PSObject.Properties.Name -contains 'prev_sha256') {
                $actualPrev = $obj.prev_sha256
            }
            if (-not $actualPrev) {
                # Legacy entry without a chain link.
                $skipped++
                $expected = $hash
                continue
            }
            if ($actualPrev -ne $expected) {
                Write-Host ("[x] hash chain broken at line {0}" -f $lineNo) -ForegroundColor Red
                Write-Host ("      expected prev_sha256 = {0}" -f $expected)
                Write-Host ("      actual   prev_sha256 = {0}" -f $actualPrev)
                exit 1
            }
            $entries++
            $expected = $hash
        }
    } finally {
        $reader.Dispose()
        $sha.Dispose()
    }
} catch {
    Write-Host "[x] error reading $($Path): $($_.Exception.Message)" -ForegroundColor Red
    exit 2
}

if ($skipped -gt 0) {
    Write-Host ("[+] audit chain OK ({0} entries, {1} legacy/non-JSON lines)" -f $entries, $skipped) -ForegroundColor Green
} else {
    Write-Host ("[+] audit chain OK ({0} entries)" -f $entries) -ForegroundColor Green
}
exit 0
