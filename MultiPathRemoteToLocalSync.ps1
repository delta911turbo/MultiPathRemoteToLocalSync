<#
.SYNOPSIS 
WinSCP - MultiPath Remote to Local Sync
2.0.0

.DESCRIPTION
	      Originally based off the functionality of KeepLocalUpToDate.WinSCPextension.ps1 script which is provided in the 
	extension folder of WinSCP 5.9.2+. To improve the ability of a closed functionality script, rewrote the enitire thing in
	powershell, besides the last part, syncing, which will eventually be rewriten as well. At this point it will take input of
	multiple folders, local and remote, that are accepted as pairs. Each pair will sync between and allow the contents of the
	remote to be sync'd to the local. There is a interval that allows the script to continuously run and have a delay between
	session of checking the folders provided. It will also disconnect and reconnect between each session, to ensure the
	connection maintains and does not drop at any point. This still uses the 
    
.PARAMETER ####################
          ####################
.PARAMETER ####################
	       ####################
.PARAMETER  ####################
          ####################
.PARAMETER  ####################
	        ####################
.PARAMETER  ####################
          ####################
.PARAMETER ####################
	         ####################
        
.PARAMETER ####################
         ####################                
.PARAMETER ####################
          ####################

.EXAMPLE
          ####################
          ####################
.NOTES
	        With the initial version of this script it setup for 3 remote/local folders that are manually set through parameters. The 
          original WinSCP script and documentation - https://winscp.net/eng/docs/library_example_keep_local_directory_up_to_date 
.LINK
	        https://github.com/delta911turbo/MultiPathRemoteToLocalSync
#>

[cmdletbinding()]
Param(
    
    [Parameter(ValueFromPipeline=$True)]
        [String[]] $multiplePaths, ## Multiple path input format:  "localpath1","remotepath1","localpath2","remotepath2" ##
    [Parameter(Mandatory = $True, ValueFromPipeline=$true)]
    [ValidateScript({ (($PsItem -eq "ftp") -or ($PsItem -eq "sftp") -or ($PsItem -eq "scp") -or ($PsItem -eq "webdev")) })]  ## Verifies input is a valid protocol ##
        $sessionProtocol,  ## Valid protocols:  ftp, sftp, scp, webdav ##
    [Parameter(Mandatory = $True, ValueFromPipeline=$true)]
    [ValidateScript({ (($PsItem -ne $null) -and ($PsItem -ne [String]::Empty)) })] ## Verifies input was not NULL ##
        $sessionHostName,
    [Parameter(Mandatory = $True, ValueFromPipeline=$true)]
    [ValidateScript({ (($PsItem -ne $null) -and ($PsItem -ne [String]::Empty)) })] ## Verifies input was not NULL ##
        $sessionUserName,
    [Parameter(Mandatory = $True, ValueFromPipeline=$true)]
        $sessionPassword,
    [parameter(Mandatory=$true, ValueFromPipeline=$true)]
        $sessionSSHHostKeyFingerprint,
    [parameter(Mandatory=$true, ValueFromPipeline=$true)]
         $localPath,
    [parameter(Mandatory=$true, ValueFromPipeline=$true)]
         $remotePath, 
    [parameter(Mandatory=$true, ValueFromPipeline=$true)]
         $interval = 300
)

Write-Verbose "################## Starting Variable Values ##################"
Write-Verbose "Multipath: $multiplePaths"
Write-Verbose "Protocol: $sessionProtocol"
Write-Verbose "HostName: $sessionHostName"
Write-Verbose "Username: $sessionUserName"
Write-Verbose "Password: $sessionPassword"
Write-Verbose "Localpath: $localPath"
Write-Verbose "Remotepath: $remotePath"
Write-Verbose "SSHHostKeyFingerprint: $sessionSSHHostKeyFingerprint `n"

function DataValidation {

    ## Testing steps and data flow ##
    Write-Verbose "################## Data Validation Values ##################"
    Write-Verbose "Multipath: $multiplePaths"
    Write-Verbose "Protocol: $sessionProtocol"
    Write-Verbose "HostName: $sessionHostName"
    Write-Verbose "Username: $sessionUserName"
    Write-Verbose "Password: $sessionPassword"
    Write-Verbose "Localpath: $localPath"
    Write-Verbose "Remotepath: $remotePath"
    Write-Verbose "SSHHostKeyFingerprint: $sessionSSHHostKeyFingerprint `n"

    ## Checks for secure protocols, SFTP and SCP, and verifies/aquires SSH Host Key Fingerprint ##
    if ((!$sessionSSHHostKeyFingerprint) -and ($sessionProtocol -eq "sftp") -or ($sessionProtocol -eq "scp")) { 
    
        $sessionSSHHostKeyFingerprint = Read-host "SSH HostKey Fingerprint: "
    
        ## Verifies SSH Host Key Fingerprint was provided ##
        if (!$sessionSSHHostKeyFingerprint) {throw "SSH Host Key Fingerprint is required for secure protocols, SFTP and SCP. Please visit https://winscp.net/eng/docs/faq_hostkey for more information."}

    }    

    ## Check if $multiplePaths variable contains data and verifies that the local paths are valid ##
    if ($multiplePaths) {

        $i = 0
        $pathSet = 1
    
        do {
                
            if (!$multiplePaths[$i]) {throw "Missing Local Path $pathSet"} ## Verifies that local path is not NULL ##
            if (Test-path $multiplePaths[$i]) {} else {throw "Local Path $pathSet is invalid"} ## Test local path is valid ##
            write-verbose "############ Local Path $pathSet ###############"
            write-verbose $multiplePaths[$i]

            $i++

            if (!$multiplePaths[$i]) {throw "Missing Remote Path $pathSet"} ## Verifies that remote path is not NULL ##
            
            write-verbose "############ Remote Path $pathSet ###############"
            write-verbose $multiplePaths[$i]
            
        
            $i++
            $pathSet++
        
        
        } while ($i -lt $multiplePaths.count)      
    
    } else { 

        ## Request user input for local path if one is not provided as a parameter when the script is called ##
        if (!$localPath) { $localPath = Read-host "Local path: " }
    
        ## Requet user input for remote path if one is not provided as a parameter when the script is called ##
        if (!$remotePath) { $remotePath = Read-host "Remote path: " }
 
    } 

    return

}

function WinSCPSync {

    Param (
        [string] $multiLocalPath,
        [string] $multiRemotePath 
    )
        
    if ($multiLocalPath) { $localPath = $multiLocalPath }
    if ($multiRemotePath) { $remotePath = $multiRemotePath }

    Write-Verbose "################## Sync Values ##################"
    Write-Verbose "Multipath: $multiplePaths"
    Write-Verbose "Protocol: $sessionProtocol"
    Write-Verbose "HostName: $sessionHostName"
    Write-Verbose "Username: $sessionUserName"
    Write-Verbose "Password: $sessionPassword"
    Write-Verbose "Localpath: $localPath"
    Write-Verbose "Remotepath: $remotePath"
    Write-Verbose "SSHHostKeyFingerprint: $sessionSSHHostKeyFingerprint"
    
    ## Generating list of files from the local path ##
    $localFiles = Get-ChildItem $localPath | Select -Property Name

    ## Verbose printout of Local Files found ##
    Write-Verbose "################## Local Files in $localPath #####################"
    $localFiles | ForEach-Object { Write-Verbose $_.Name}

    ## Generating list of files from remote path ##
    $remoteFiles = $session.ListDirectory($remotePath).Files | Select -Property Name

    ## Verbose printout of Remote Files found ##
    Write-Verbose "################## Remote Files in $remotePath ####################"
    $remoteFiles | Where-Object {$_.Name -ne ".."} | ForEach-Object {Write-Verbose $_.Name}
    
    Write-host "###################### Comparing folders $remotePath and $localPath ##################"  
    ## Comparing files found in local path to files found in remote path ##  
    Compare-Object -ReferenceObject $remoteFiles -Property Name -DifferenceObject @($localFiles | Select-Object) | Where-Object { $_.SideIndicator -eq "<=" -and $_.Name -ne ".." } | Foreach-Object {
        
        ## Syncing any missing files from local path ##
        Write-Host "Syncing new file $remotePath$($_.Name)"
        $session.GetFiles($session.EscapeFileMask($remotePath + $($_.Name)), $localPath).check()
    }
}


DataValidation

Add-Type -Path "..\WinSCPnet.dll"

# PowerShell While Loop
$i =9 
While ($i -gt 8) {

    $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
        Protocol = [WinSCP.Protocol]::$sessionProtocol
        HostName = $sessionHostName
        UserName = $sessionUserName
        Password = $sessionPassword
    }
    
    $session = New-Object WinSCP.Session

    ## Connecting to remote server ## 
    Write-Host "############### Connecting... ###############"
    $session.Open($sessionOptions)

if (!$multiplePaths) { WinSCPSync } else {
    
    $localIndex = 0
    $remoteIndex =1

    do { 
        
        if (!$multiplePaths[$localIndex]) {throw "Missing Local Path $localIndex"}

        $localPath = $multiplePaths[$localIndex]

        if (!$multiplePaths[$remoteIndex]) {throw "Missing Remote Path $remoteIndex"} ## Verifies that remote path is not NULL ##
            
        $remotePath = $multiplePaths[$remoteIndex]

        WinSCPSync

        $localIndex++
        $localIndex++
        $remoteIndex++
        $remoteIndex++
    
    } while ($remoteIndex -lt $multiplePaths.count)

}

write-host "############## Disconnecting... ##############"
    # Disconnect, clean up
    $session.Dispose()

Write-Host "Waiting for $interval seconds, press Ctrl+C to abort..."
            $wait = [int]$interval
            # Wait for 1 second in a loop, to make the waiting breakable
            while ($wait -gt 0)
            {
                Start-Sleep -Seconds 1
                $wait--
            }

}
