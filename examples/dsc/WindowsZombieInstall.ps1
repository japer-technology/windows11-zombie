Configuration WindowsZombieInstall {
    param(
        [string]$ReleaseVersion = '0.0.0',
        [string]$StageDir = 'C:\ProgramData\windows-zombie-src'
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Node 'localhost' {
        File Stage {
            Ensure          = 'Present'
            Type            = 'Directory'
            DestinationPath = $StageDir
        }

        Script Install {
            DependsOn = '[File]Stage'
            GetScript = { @{ Result = (Test-Path "$using:StageDir\scripts\Install.ps1") } }
            TestScript = {
                $svc = Get-Service -Name 'WindowsZombie-Chat' -ErrorAction SilentlyContinue
                return ($svc -and $svc.Status -eq 'Running')
            }
            SetScript = {
                $zip = Join-Path $using:StageDir 'release.zip'
                $url = "https://github.com/japer-technology/windows-zombie/releases/download/v$using:ReleaseVersion/windows-zombie-$using:ReleaseVersion.zip"
                Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
                Expand-Archive -Path $zip -DestinationPath $using:StageDir -Force
                & (Join-Path $using:StageDir 'scripts\Install.ps1') install -AssumeYes
            }
        }
    }
}
