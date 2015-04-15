

Function QuickWebsiteDeployment([string]$SiteName = "Default Website", [string]$SitePath = 'D:\InetSrv\wwwroot', [string]$SiteUrl = 'http://localhost/', [boolean]$suppressRollbackWarning = $false)
{
    # Check to see if production folder exists.   If it doesn't exist, exit with errors...
    $ProductionPathExists = Test-Path $SitePath;
    if ($ProductionPathExists -eq $true)
    {
        # Check to see if '-Offline' folder exists, if it doesn't we will create it for next time by copying the current production folder and ACLs to a new '-Offline' folder.
        $OfflinePathExists = Test-Path $SitePath'-Offline';
        if ($OfflinePathExists -eq $false)
        {
            $ProductionPath = $SitePath + '\*';
            icacls $SitePath /save AclFile /T;
            Copy-Item $SitePath $SitePath'-Offline' -Recurse;
            $OfflinePath = $SitePath + '-Offline\';
            icacls $OfflinePath /restore AclFile;
            # Mama taught us to cleanup after ourselves...
            Remove-Item AclFile;
	        Write-Output 'Nothing to deploy.';
	        Write-Output 'Created new folder: '$OfflinePath;
        }
        else
        {
            # Accidental rollback protection
            $ProductionLastModified = [datetime](Get-ItemProperty -Path $SitePath).lastwritetime;
            $OfflineLastModified = [datetime](Get-ItemProperty -Path $SitePath'-Offline').lastwritetime;
            $FolderTimeDelta = New-TimeSpan -Start $OfflineLastModified -End $ProductionLastModified;
            $ContinueProcessing = 'Y';  
            if (($FolderTimeDelta.TotalMilliseconds -gt 0) -and (suppressRollbackWarning -eq $false))
            {
                $ContinueProcessing = Read-Host 'The production folder appears to be newer than your -Offline folder.   You are about to rollback to an older version.   Would you like to continue? [Y/N]';
            }

            if ($ContinueProcessing -eq 'Y')
            {
                # Rename the '-Offline' folder to '-Loading'
                Rename-Item $SitePath'-Offline' $SitePath'-Loading' -Force -ErrorAction Stop;

                # Stop Application Pool & Website
                Stop-Website -Name $SiteName -ErrorAction Stop;
                Stop-WebAppPool -Name $SiteName -ErrorAction Stop;

                # Rename the production folder to '-Offline'
                Rename-Item $SitePath $SitePath'-Offline' -Force -ErrorAction Stop;

                # Rename the '-Loading' folder to be the production folder 
                Rename-Item $SitePath'-Loading' $SitePath -Force  -ErrorAction Stop;

                # Start Application Pool & Website
                Start-WebAppPool -Name $SiteName -ErrorAction Stop;
                Start-Website -Name $SiteName;
    
                # Make Initial Web Request	
                Invoke-WebRequest -Uri $SiteUrl;
                Write-Output 'Deployment complete.';
            }
            else
            {
                Write-Output 'Deployment aborted by user.';
            }
        }
    }
    else
    {
        Write-Output 'Could not find '$SitePath;
        Write-Output 'Please check your configuration and try again.';
    }
}

QuickWebsiteDeployment -SiteName 'Example' -SitePath 'D:\InetSrv\example.com' -SiteUrl 'https://www.example.com/';
