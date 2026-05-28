#Requires -Version 7.0
#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Unit tests for scripts/Common.ps1.
#>

BeforeAll {
    $script:RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    # Common.ps1 reads $env:ProgramData and dependent vars at dot-source
    # time, so use a tmp dir.
    $script:TmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("zombie-pester-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $script:TmpRoot -Force | Out-Null
    $env:AI_ZOMBIE_ROOT = $script:TmpRoot
    if (-not $env:ProgramData) { $env:ProgramData = $script:TmpRoot }
    $env:ZOMBIE_NONINTERACTIVE = '1'
    . (Join-Path $script:RepoRoot 'scripts/Common.ps1')
}

AfterAll {
    if (Test-Path $script:TmpRoot) {
        Remove-Item -Recurse -Force $script:TmpRoot -ErrorAction SilentlyContinue
    }
}

Describe 'Test-ValidAgentUsername' {
    It 'accepts a normal lowercase name' {
        Test-ValidAgentUsername 'zombie' | Should -BeTrue
    }
    It 'rejects reserved Windows names' {
        Test-ValidAgentUsername 'Administrator' | Should -BeFalse
        Test-ValidAgentUsername 'SYSTEM' | Should -BeFalse
        Test-ValidAgentUsername 'Guest' | Should -BeFalse
    }
    It 'rejects empty or whitespace' {
        Test-ValidAgentUsername '' | Should -BeFalse
        Test-ValidAgentUsername '   ' | Should -BeFalse
    }
    It 'rejects names starting with a digit' {
        Test-ValidAgentUsername '1abc' | Should -BeFalse
    }
    It 'rejects names longer than 20 chars' {
        Test-ValidAgentUsername ('a' * 21) | Should -BeFalse
    }
    It 'accepts dotted and dashed identifiers' {
        Test-ValidAgentUsername 'corp.admin' | Should -BeTrue
        Test-ValidAgentUsername 'svc-zombie' | Should -BeTrue
    }
}

Describe 'AzConfig and Update-AzPaths' {
    It 'derives every path from InstallRoot' {
        $script:AzConfig.InstallRoot | Should -Be $script:TmpRoot
        $script:AzConfig.LogDir      | Should -Be (Join-Path $script:TmpRoot 'logs')
        $script:AzConfig.StateDir    | Should -Be (Join-Path $script:TmpRoot 'state')
        $script:AzConfig.SecretsFile | Should -Be (Join-Path (Join-Path $script:TmpRoot 'secrets') 'env')
        $script:AzConfig.AuditLog    | Should -Be (Join-Path (Join-Path $script:TmpRoot 'logs') 'audit.log')
    }
}

Describe 'Ensure-Directory' {
    It 'creates a missing directory' {
        $target = Join-Path $script:TmpRoot 'new-dir'
        if (Test-Path $target) { Remove-Item -Recurse -Force $target }
        Ensure-Directory $target | Should -BeTrue
        Test-Path $target | Should -BeTrue
    }
    It 'is a no-op when the directory exists' {
        $target = Join-Path $script:TmpRoot 'exists'
        New-Item -ItemType Directory -Force -Path $target | Out-Null
        Ensure-Directory $target | Should -BeFalse
    }
}

Describe 'New-AiZombieBackup and Restore-AiZombieBackup' -Tag 'Integration' {
    BeforeAll {
        $script:BackupTmp = Join-Path $script:TmpRoot 'backup-test-state'
        New-Item -ItemType Directory -Force -Path (Join-Path $script:TmpRoot 'etc') | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $script:TmpRoot 'secrets') | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $script:TmpRoot 'state') | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $script:TmpRoot 'logs') | Out-Null
        'fake policy' | Set-Content (Join-Path (Join-Path $script:TmpRoot 'etc') 'policy.yaml')
        'OPENAI_API_KEY=sk-test-12345' | Set-Content (Join-Path (Join-Path $script:TmpRoot 'secrets') 'env')
        '{"ok":true}' | Set-Content (Join-Path (Join-Path $script:TmpRoot 'state') 'health.json')
    }
    It 'creates a verifiable zip' {
        $dest = Join-Path $script:TmpRoot 'backups'
        $zip = New-AiZombieBackup -DestDir $dest -Retain 5
        Test-Path $zip | Should -BeTrue
        # Manifest should be inside.
        $stage = Join-Path ([System.IO.Path]::GetTempPath()) ("verify-" + [Guid]::NewGuid().ToString('N'))
        Expand-Archive -LiteralPath $zip -DestinationPath $stage
        try {
            Test-Path (Join-Path $stage 'SHA256SUMS') | Should -BeTrue
            (Get-Content (Join-Path $stage 'SHA256SUMS')).Count | Should -BeGreaterThan 0
        } finally {
            Remove-Item -Recurse -Force $stage
        }
    }
    It 'restores from the zip' {
        $dest = Join-Path $script:TmpRoot 'backups'
        $zip = Get-ChildItem $dest -Filter '*.zip' | Select-Object -First 1 -ExpandProperty FullName
        # Delete the secrets and restore.
        Remove-Item (Join-Path (Join-Path $script:TmpRoot 'secrets') 'env') -Force
        Restore-AiZombieBackup -Path $zip -Force
        Test-Path (Join-Path (Join-Path $script:TmpRoot 'secrets') 'env') | Should -BeTrue
    }
}
