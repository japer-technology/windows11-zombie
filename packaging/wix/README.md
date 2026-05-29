# WiX (MSI) skeleton

`WindowsZombie.wxs` lays down the unzipped payload to
`%ProgramFiles%\windows-zombie\` and runs `Install.ps1 install` as a
custom action. Build with WiX 4:

```powershell
wix build packaging\wix\WindowsZombie.wxs -o dist\windows-zombie.msi
```

The MSI is intended for Group Policy / Intune deployment. Detection
rule: existence of `%ProgramData%\AiZombie\bin\windows-zombie.cmd`.
Uninstall command: `Install.ps1 uninstall -AssumeYes`.
