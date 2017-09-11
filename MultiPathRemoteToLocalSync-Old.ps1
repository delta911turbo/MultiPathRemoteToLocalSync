<#
.SYNOPSIS 
WinSCP - MultiPath Remote to Local Sync
v1.0.0

.DESCRIPTION
	      Modified version of KeepLocalUpToDate.WinSCPextension.ps1 script which is provided in the extension folder of WinSCP 5.9.2+.    
        Instead of having to use the file mask option to include/exclude subfolders based off a root folder, this script allows for
        input of both multiple remote and local folders that individually synchronized. The remote and local paths are labeled as    
        Primary, Secondary, and Tertiary. 
    
.PARAMETER localPathPrimary
         Primary local path
.PARAMETER remotePathPrimary
	       Primary remote path
.PARAMETER localPathPrimary
         Secondary local path
.PARAMETER remotePathPrimary
	       Secondary remote path
.PARAMETER localPathPrimary
         Tertiary local path
.PARAMETER remotePathPrimary
	       Tertiary remote path
        
.PARAMETER sessionLogPath
         Path and file of the log that is by default disabled if not defined at the time of running the script. The log output is                the verbose of all files found on both the local and remote sources.
.PARAMETER interval
          Set time that the script will pause and wait before starting over. Sleep timer is in seconds and during the wait period the  
          script can be canceled by pressing Ctrl-C. It has a default value set to 30 seconds, but can be adjusted at the time of 
          running the script.

.EXAMPLE
          .\MultiPathRemoteToLocalSync.ps1 -localPathPrimary "E:\Backup\PrimaryVolume\" -remotePathPrimary "/Vol_Pri/" -localPathSecondary "E:\Backup\SecondaryVolume\" -remotePathSecondary "/Vol_Sec/" -localPathTertiary "E:\Backup\TertiaryVolume\" -remotePathTertiary "/Vol_Ter/" -sessionLogPath "E:\Backup\SyncLog.txt" -interval "300" -delete -continueOnError
          
          .\MultiPathRemoteToLocalSync.ps1 -localPathPrimary "E:\Backup\PrimaryVolume\" -remotePathPrimary "/Vol_Pri/" -localPathSecondary "E:\Backup\SecondaryVolume\" -remotePathSecondary "/Vol_Sec/" -localPathTertiary "E:\Backup\TertiaryVolume\" -remotePathTertiary "/Vol_Ter/"
          
.NOTES
	        With the initial version of this script it setup for 3 remote/local folders that are manually set through parameters. The 
          original WinSCP script and documentation - https://winscp.net/eng/docs/library_example_keep_local_directory_up_to_date 
.LINK
	        https://github.com/delta911turbo/MultiPathRemoteToLocalSync
#>

param (
    [Parameter(Mandatory = $True)]
    $localPathPrimary,
    [Parameter(Mandatory = $True)]
    $remotePathPrimary,
    [Parameter(Mandatory = $True)]
    $localPathSecondary,
    [Parameter(Mandatory = $True)]
    $remotePathSecondary,
    [Parameter(Mandatory = $True)]
    $localPathTertiary,
    [Parameter(Mandatory = $True)]
    $remotePathTertiary,    
    $sessionLogPath = $Null,
    $interval = 30,
    [switch]
    $delete
    [switch]
    $continueOnError
)

function SyncPrimary ($localPathPrimary, $remotePathPrimary, $sessionLogPath, $interval, $delete, $continueOnError) {

    Add-Type -Path ("..\WinSCPnet.dll")

    # Setup session options
    $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
        Protocol = [WinSCP.Protocol]::ftp
        HostName = "ftp.example.com"
        UserName = "exampleuser"
        Password = "examplepassword"
      }
    

    $session = New-Object WinSCP.Session
    
    # Optimization
    # (do not waste time enumerating files, if you do not need to scan for deleted files)
    if ($delete) 
    {
        $localFilesPrimary = Get-ChildItem -Recurse -Path $localPathPrimary
    }

    
        $session.SessionLogPath = $sessionLogPath

        Write-Host "Connecting..."
        $session.Open($sessionOptions)


            Write-Host "Synchronizing changes between $localPathPrimary and $remotePathPrimary"
            $result = $session.SynchronizeDirectories([WinSCP.SynchronizationMode]::Local, $localPathPrimary, $remotePathPrimary, $delete)

            $changed = $False

            if (!$result.IsSuccess)
            {
              if ($continueOnError)
              {
                Write-Host ("Error: {0}" -f $result.Failures[0].Message)
                $changed = $True
              }
              else
              {
                $result.Check()
              }
            }

            # Print updated files
            foreach ($download in $result.Downloads)
            {
                Write-Host ("{0} <= {1}" -f $download.Destination, $download.FileName)
                $changed = $True
            }

            if ($delete)
            {
                # scan for removed local files (the $result does not include them)
                $localFilesPrimary2 = Get-ChildItem -Recurse -Path $localPathPrimary

                if ($localFilesPrimary)
                {
                    $changes = Compare-Object -DifferenceObject $localFilesPrimary2 -ReferenceObject $localFilesPrimary
                
                    $removedFiles =
                        $changes |
                        Where-Object -FilterScript { $_.SideIndicator -eq "<=" } |
                        Select-Object -ExpandProperty InputObject

                    # Print removed local files
                    foreach ($removedFile in $removedFiles)
                    {
                        Write-Host ("{0} deleted" -f $removedFile)
                        $changed = $True
                    }
                }

                $localFilesPrimary = $localFilesPrimary2
            }

            if ($changed)
            {
                
            }
            else
            {
                Write-Host "No change."
            }            

        write-host "Disconnecting..."
        # Disconnect, clean up
        $session.Dispose()  
}


function SyncSecondary ($localPathSecondary, $remotePathSecondary, $sessionLogPath, $interval, $delete, $continueOnError) {
 
    # Setup session options
    $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
        Protocol = [WinSCP.Protocol]::ftp
        HostName = "ftp.example.com"
        UserName = "exampleuser"
        Password = "examplepassword"
      }
    

    $session = New-Object WinSCP.Session
    
    # Optimization
    # (do not waste time enumerating files, if you do not need to scan for deleted files)
    if ($delete) 
    {
        $localFilesSecondary = Get-ChildItem -Recurse -Path $localPathSecondary
    }

    
        $session.SessionLogPath = $sessionLogPath

        Write-Host "Connecting..."
        $session.Open($sessionOptions)

        
            Write-Host "Synchronizing changes between $localPathSecondary and $remotePathSecondary"
            $result = $session.SynchronizeDirectories([WinSCP.SynchronizationMode]::Local, $localPathSecondary, $remotePathSecondary, $delete)

            $changed = $False

            if (!$result.IsSuccess)
            {
              if ($continueOnError)
              {
                Write-Host ("Error: {0}" -f $result.Failures[0].Message)
                $changed = $True
              }
              else
              {
                $result.Check()
              }
            }

            # Print updated files
            foreach ($download in $result.Downloads)
            {
                Write-Host ("{0} <= {1}" -f $download.Destination, $download.FileName)
                $changed = $True
            }

            if ($delete)
            {
                # scan for removed local files (the $result does not include them)
                $localFilesSecondary2 = Get-ChildItem -Recurse -Path $localPathSecondary

                if ($localFilesSecondary)
                {
                    $changes = Compare-Object -DifferenceObject $localFilesSecondary2 -ReferenceObject $localFilesSecondary
                
                    $removedFiles =
                        $changes |
                        Where-Object -FilterScript { $_.SideIndicator -eq "<=" } |
                        Select-Object -ExpandProperty InputObject

                    # Print removed local files
                    foreach ($removedFile in $removedFiles)
                    {
                        Write-Host ("{0} deleted" -f $removedFile)
                        $changed = $True
                    }
                }

                $localFilesSecondary = $localFilesSecondary2
            }

            if ($changed)
            {
                
            }
            else
            {
                Write-Host "No change."
            }            
            Write-Host

        # Disconnect, clean up
        $session.Dispose()
}

function SyncTertiary ($localPathTertiary, $remotePathTertiary, $continueOnError, $sessionLogPath, $interval, $delete, $continueOnError) {
    # Setup session options
    $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
        Protocol = [WinSCP.Protocol]::ftp
        HostName = "ftp.example.com"
        UserName = "exampleuser"
        Password = "examplepassword"
      }
    

    $session = New-Object WinSCP.Session
    
    # Optimization
    # (do not waste time enumerating files, if you do not need to scan for deleted files)
    if ($delete) 
    {
        $localFilesTertiary = Get-ChildItem -Recurse -Path $localPathTertiary
    }

    
        $session.SessionLogPath = $sessionLogPath

        Write-Host "Connecting..."
        $session.Open($sessionOptions)

        
            Write-Host "Synchronizing changes between $localPathTertiary and $remotePathTertiary"
            $result = $session.SynchronizeDirectories([WinSCP.SynchronizationMode]::Local, $localPathTertiary, $remotePathTertiary, $delete)

            $changed = $False

            if (!$result.IsSuccess)
            {
              if ($continueOnError)
              {
                Write-Host ("Error: {0}" -f $result.Failures[0].Message)
                $changed = $True
              }
              else
              {
                $result.Check()
              }
            }

            # Print updated files
            foreach ($download in $result.Downloads)
            {
                Write-Host ("{0} <= {1}" -f $download.Destination, $download.FileName)
                $changed = $True
            }

            if ($delete)
            {
                # scan for removed local files (the $result does not include them)
                $localFilesTertiary2 = Get-ChildItem -Recurse -Path $localPathTertiary

                if ($localFilesTertiary)
                {
                    $changes = Compare-Object -DifferenceObject $localFilesTertiary2 -ReferenceObject $localFilesTertiary
                
                    $removedFiles =
                        $changes |
                        Where-Object -FilterScript { $_.SideIndicator -eq "<=" } |
                        Select-Object -ExpandProperty InputObject

                    # Print removed local files
                    foreach ($removedFile in $removedFiles)
                    {
                        Write-Host ("{0} deleted" -f $removedFile)
                        $changed = $True
                    }
                }

                $localFilesTertiary = $localFilesTertiary2
            }

            if ($changed)
            {
                if ($beep)
                {
                    [System.Console]::Beep()
                }
            }
            else
            {
                Write-Host "No change."
            }            
            Write-Host
        
    

    
        # Disconnect, clean up
        $session.Dispose()
 
}


# PowerShell While Loop
$i =9 
While ($i -gt 8) {

SyncPrimary $sessionUrl $localPathPrimary $remotePathPrimary $delete $beep $continueOnError $sessionLogPath
SyncSecondary $sessionUrl $localPathSecondary $remotePathSecondary $delete $beep $continueOnError $sessionLogPath
SyncTertiary $sessionUrl $localPathTertiary $remotePathTertiary $delete $beep $continueOnError $sessionLogPath

Write-Host "Waiting for $interval seconds, press Ctrl+C to abort..."
            $wait = [int]$interval
            # Wait for 1 second in a loop, to make the waiting breakable
            while ($wait -gt 0)
            {
                Start-Sleep -Seconds 1
                $wait--
            }

}
       
# Never exits cleanly
exit 1
