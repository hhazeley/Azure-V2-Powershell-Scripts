#Deploy script to machine using Custom Script Extension
#This will created a firewall rule for 'WinRM HTTPS" and Configure WinRM for HTTPS using certificate
Param(
    $StorageA,
    $StorageAAK,
    $DNSlabelName,
    $password,
    $DNSLabel,
    $thumbprint
)
New-NetFirewallRule -Name "WinRM HTTPS" -DisplayName "WinRM HTTPS" -Enabled True -Profile Any -Action Allow -Direction Inbound -LocalPort 5986 -Protocol TCP
net use X: \\$StorageA.file.core.windows.net\cert /u:$StorageA $StorageAAK
Import-PfxCertificate -FilePath X:\$DNSlabelName.pfx -CertStoreLocation Cert:\LocalMachine\My\ -Password (ConvertTo-SecureString "$password" -AsPlainText -Force) -Exportable 
New-WSManInstance -ResourceURI winrm/config/Listener -SelectorSet @{Address='*';Transport="HTTPS"} -ValueSet @{Hostname="$DNSLabel";CertificateThumbprint="$thumbprint"}
net use X: /delete 
