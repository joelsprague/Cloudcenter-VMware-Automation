Import-Module VMWare.VIMAutomation.Core

$VIServer = Read-Host "Input address of Vsphere Server"

Connect-VIServer $VIServer

#Find OVAs
$CCMOVA = dir -filter *ccm* | %{$_.FullName}
$CCOOVA = dir -filter *cco* | %{$_.FullName}
$LOGOVA = dir -filter *logcollector* | %{$_.FullName}
$DBOVA = dir -filter *postgres* | %{$_.FullName}
$AMQPOVA = dir -filter *rabbit* | %{$_.FullName}
$WORKEROVA = dir -filter *worker* | %{$_.FullName}

#Configure Variables
$CCMName = "ccc_man"
$CCOName = "ccc_orch"
$LogName = "ccc_log"
$DBName = "ccc_db"
$AMQPName = "ccc_amqp"
$WORKERName = "ccc_worker"
$Diskformat = "Thin"

#Retrieve and choose Vsphere Resources
Get-Cluster | fl Name
$VsphereCluster = Read-Host "Choose cluster to install virtual machines to"
$Cluster = Get-Cluster -name $VsphereCluster

Get-Datastore | fl Name
$VsphereDatastore = Read-Host "Choose datastore to store virtual machines"

Get-VirtualPortGroup | fl Name
$VMPortgroup = Read-Host "Choose portgroup for VM networking"

#Import and start OVAs.  Target import to host with lowest memory usage
$VMHost = Get-cluster $VsphereCluster | Get-VMHost | Sort MemoryGB | Select -first 1
Import-VApp -Source $CCMOVA -Name $CCMName -VMHost $VMHost -Location $Cluster -Datastore $VsphereDatastore -DiskStorageFormat $Diskformat -confirm:$false
Start-VM $CCMName

$VMHost = Get-cluster $VsphereCluster | Get-VMHost | Sort MemoryGB | Select -first 1
Import-VApp -Source $CCOOVA -Name $CCOName -VMHost $VMHost -Location $Cluster -Datastore $VsphereDatastore -DiskStorageFormat $Diskformat -confirm:$false
Start-VM $CCOName

$VMHost = Get-cluster $VsphereCluster | Get-VMHost | Sort MemoryGB | Select -first 1
Import-VApp -Source $LOGOVA -Name $LOGName -VMHost $VMHost -Location $Cluster -Datastore $VsphereDatastore -DiskStorageFormat $Diskformat -confirm:$false
Start-VM $LOGName

$VMHost = Get-cluster $VsphereCluster | Get-VMHost | Sort MemoryGB | Select -first 1
Import-VApp -Source $DBOVA -Name $DBName -VMHost $VMHost -Location $Cluster -Datastore $VsphereDatastore -DiskStorageFormat $Diskformat -confirm:$false
Start-VM $DBName

$VMHost = Get-cluster $VsphereCluster | Get-VMHost | Sort MemoryGB | Select -first 1
Import-VApp -Source $AMQPOVA -Name $AMQPName -VMHost $VMHost -Location $Cluster -Datastore $VsphereDatastore -DiskStorageFormat $Diskformat -confirm:$false
Start-VM $AMQPName

$VMHost = Get-cluster $VsphereCluster | Get-VMHost | Sort MemoryGB | Select -first 1
Import-VApp -Source $WORKEROVA -Name $WORKERName -VMHost $VMHost -Location $Cluster -Datastore $VsphereDatastore -DiskStorageFormat $Diskformat -confirm:$false

#Reconfigure virtual machines
$CCMIP = "192.168.0.60/24"
$CCOIP = "192.168.0.61/24"
$LOGIP = "192.168.0.62/24"
$DBIP = "192.168.0.63/24"
$AMQPIP = "192.168.0.64/24"
$GATEWAY = "192.168.0.1"
$PASSWORD = "Ch@ngem3"

#Reusable function to create configuration script for each virtual machine
function Configure-VM {

    Param ([string]$IP, [string]$GW, [string]$HOSTNAME, [string]$ROOTPASS)

$VMNetwork = @"
nmcli con mod eth0 ipv4.addresses $IP
nmcli con mod eth0 ipv4.gateway $GW
nmcli con mod eth0 ipv4.method manual
hostnamectl set-hostname $HOSTNAME
"@

Write-Output $VMNetwork
}

$CHANGEROOT = @"
echo $PASSWORD | passwd --stdin root
"@

$Script = Configure-VM -IP $CCMIP -GW $GATEWAY -HOSTNAME $CCMName -ROOTPASS $PASSWORD
Invoke-VMscript -VM $CCMName -Scripttext $Script -Guestuser root -Guestpassword welcome2cliqr -Scripttype Bash
Invoke-VMscript -VM $CCMName -Scripttext $CHANGEROOT -Guestuser root -Guestpassword welcome2cliqr -Scripttype Bash
Restart-VM -VM $CCMName -RunAsync -Confirm:$false

$Script = Configure-VM -IP $CCOIP -GW $GATEWAY -HOSTNAME $CCOName -ROOTPASS $PASSWORD
Invoke-VMscript -VM $CCOName -Scripttext $Script -Guestuser root -Guestpassword welcome2cliqr -Scripttype Bash
Invoke-VMscript -VM $CCOName -Scripttext $CHANGEROOT -Guestuser root -Guestpassword welcome2cliqr -Scripttype Bash
Restart-VM -VM $CCOName -RunAsync -Confirm:$false

$Script = Configure-VM -IP $LOGIP -GW $GATEWAY -HOSTNAME $LOGName -ROOTPASS $PASSWORD
Invoke-VMscript -VM $LOGName -Scripttext $Script -Guestuser root -Guestpassword welcome2cliqr -Scripttype Bash
Invoke-VMscript -VM $LOGName -Scripttext $CHANGEROOT -Guestuser root -Guestpassword welcome2cliqr -Scripttype Bash
Restart-VM -VM $LOGName -RunAsync -Confirm:$false

$Script = Configure-VM -IP $DBIP -GW $GATEWAY -HOSTNAME $DBName -ROOTPASS $PASSWORD
Invoke-VMscript -VM $DBName -Scripttext $Script -Guestuser root -Guestpassword welcome2cliqr -Scripttype Bash
Invoke-VMscript -VM $DBName -Scripttext $CHANGEROOT -Guestuser root -Guestpassword welcome2cliqr -Scripttype Bash
Restart-VM -VM $DBName -RunAsync -Confirm:$false

$Script = Configure-VM -IP $AMQPIP -GW $GATEWAY -HOSTNAME $AMQPName -ROOTPASS $PASSWORD
Invoke-VMscript -VM $AMQPName -Scripttext $Script -Guestuser root -Guestpassword welcome2cliqr -Scripttype Bash
Invoke-VMscript -VM $AMQPName -Scripttext $CHANGEROOT -Guestuser root -Guestpassword welcome2cliqr -Scripttype Bash
Restart-VM -VM $AMQPName -RunAsync -Confirm:$false
