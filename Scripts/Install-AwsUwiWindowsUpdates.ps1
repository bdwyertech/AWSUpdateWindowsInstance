# Copyright 2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# This software and all associated files are licensed as AWS Content under 
# the AWS Customer Agreement (the "Agreement"). You may not use this software 
# except in compliance with the Agreement. A copy of the Agreement is located 
# at http://aws.amazon.com/agreement/ or in the "license" file 
# accompanying this software. This software is distributed on an "AS IS" BASIS, 
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or implied. See the 
# Agreement for the specific language governing permissions and limitations 
# under the Agreement.

Function Install-AwsUwiWindowsUpdates
{
    <#
        .SYNOPSIS
        Performs Microsoft Windows Updates operations.

        .DESCRIPTION
        This script will can search and update the server with Microsoft Windows Updates.  It has filtering switches to help install specific updates.
        Important: If a reboot is required, it will automatically reboot the server.
        
        The Windows Updates installation process has six main steps:
        1) Reboot if required; pre-install
        2) Search for updates
        3) Filter on the search results
        4) Download updates
        5) Install updates
        6) Reboots if any updates were installed

        .PARAMETER Id
        An ID for the execution of this cmdlet.  Default ID will be a random GUID.  
        If you want to run the script idempotent, you need to pass in the same ID each time you run it.	

        .PARAMETER ExcludeKbs
        Specify one or more Microsoft Knowledge Base (KB) article IDs to exclude. Valid formats: KB9876543 or 9876543.

        .PARAMETER IncludeKbs
        Specify one or more Microsoft Knowledge Base (KB) article IDs to include. Valid formats: KB9876543 or 9876543.

        .PARAMETER Categories
        Specify one or more categories to include.
        More information can be found at https://msdn.microsoft.com/en-us/library/windows/desktop/ff357803(v=vs.85).aspx
        Valid choices are: 'CriticalUpdates','SecurityUpdates','DefinitionUpdates','Drivers','FeaturePacks','ServicePacks','Tools','UpdateRollups','Updates','Application','Connectors','DeveloperKits','Guidance','Microsoft'

        .PARAMETER Severities 
        Specify one or more severity levels to include. 
        A severity (MsrcSeverity) is the severity rating of the Microsoft Security Response Center (MSRC) bulletin that is associated with an update.
        More information can be found at https://msdn.microsoft.com/en-us/library/windows/desktop/bb294979(v=vs.85).aspx
        Valid choices are: 'Critical','Important','Low','Moderate','Unspecified'
        
        .PARAMETER PublishedDateAfter
        Specify the date that the updates should be published After.  Format must be either mm/dd/yyyy or mm-dd-yyyy or mm.dd.yyyy
        For example, if you specify 01/01/2017, you are stating that you want updates that have been published on or after 01/01/2017.
        The published date of the update is in UTC time.
        More information can be found at https://msdn.microsoft.com/en-us/library/windows/desktop/aa386901%28v=vs.85%29.aspx?f=255&MSPPError=-2147217396

        .PARAMETER PublishedDateBefore
        Specify the date that the updates should be published Before.  Format must be either mm/dd/yyyy or mm-dd-yyyy or mm.dd.yyyy
        For example, if you specify 01/01/2017, you are stating that you want updates that have been published on or before 01/01/2017.
        The published date of the update is in UTC time.
        More information can be found at https://msdn.microsoft.com/en-us/library/windows/desktop/aa386901%28v=vs.85%29.aspx?f=255&MSPPError=-2147217396

        .PARAMETER PublishedDaysOld
        Specify the amount of days old the updates must be from the published date.  Accepts positive integer values only.
        For example, if you specify 10, then you are stating that you want updates that were published 10 or more days ago.

        .PARAMETER ListOnly
        Performs a search for Windows Updates and lists what is available.  Will not download or install any updates.

        .PARAMETER NoReboot
        Will not reboot the instance after Windows Updates have been installed.

        .PARAMETER Logger
        This logger object is responsible for writing logs.  The logger is of type AWSPoshLogger.

        .PARAMETER LogLevel
        The message to write out to the log.  The following log levels are supported: Fatal, Error, Warn, Info, Debug, Trace  Default is Info. 
        Dynamic Paramater.  Available only when Logger is null. (Has not been passed.)

        .EXAMPLE
        Install-AwsUwiWindowsUpdates
        This will search for updates and install all updates that are found.  No filtering applied.

        .EXAMPLE
        Install-AwsUwiWindowsUpdates -Categories 'CriticalUpdates'
        This will search for updates and then install updates where the update is in the Category 'CriticalUpdates'

        .EXAMPLE
        Install-AwsUwiWindowsUpdates -Severities 'Critical'
        This will search for updates and then install updates where the update has the severity level 'Critical'
        
        .EXAMPLE
        Install-AwsUwiWindowsUpdates -Categories 'Driver' -Severities 'Critical'
        This will search for updates and then install  updates where the update is in the Category 'Driver' AND severity level is 'Critical'
        
        .EXAMPLE
        Install-AwsUwiWindowsUpdates -Categories 'CriticalUpdates', 'SecurityUpdates' -SeverityLevels 'Critical', 'Important'
        This will search for updates and then install updates where the update is in the categories 'CriticalUpdates' OR 'SecurityUpdates' 
        AND has the severity level 'Critical' OR 'Important'

        .EXAMPLE
        Install-AwsUwiWindowsUpdates -ListOnly
        This will search for updates only, no installation.  No filtering applied.

        .EXAMPLE
        Install-AwsUwiWindowsUpdates -NoReboot
        This will search for updates and install all updates that are found, but will not reboot.   

        .EXAMPLE
        Install-AwsUwiWindowsUpdates -ListOnly -Categories 'Driver'
        This will search for updates only, no installation.  Updates were filtered using the Category paramater.

        .EXAMPLE
        Install-AwsUwiWindowsUpdates -IncludeKbs 'KB123456','KB0987654'
        This will search for updates.  If the KB's are found in the search results, they will be installed.

        .EXAMPLE
        Install-AwsUwiWindowsUpdates -ExcludeKbs 'KB123456','KB0987654'
        This will search for updates.  All updates found in the search will be installed except for the KB's specified.

        .EXAMPLE
        Install-AwsUwiWindowsUpdates -IncludeKbs 'KB123456' -ExcludeKbs 'KB123456'
        This will search for available updates.  If the same KB is contained both IncludeKbs and ExcludeKBs, the KB will not be installed.

        .EXAMPLE
        Install-AwsUwiWindowsUpdates -Categories 'CriticalUpdates', 'SecurityUpdates' -SeverityLevels 'Critical', 'Important' -IncludeKbs 'KB123456' -ExcludeKbs 'KB098765'
        This will search for updates and then install updates where the update is in the categories 'CriticalUpdates' OR 'SecurityUpdates' 
        AND has the severity level 'Critical' OR 'Important'.  The result is a list updates.  If the IncludeKb's are in the list, they will be installed.  
        If the ExcludeKbs are in the list, they will not be installed. 
    #>

    [CmdletBinding()]
    
    Param 
    (
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$Id = [guid]::NewGuid(),

        [Parameter(Mandatory=$false)]
        [ValidatePattern("^((KB){0,1}[0-9]{1,7})$")]
        [string[]]$IncludeKbs,

        [Parameter(Mandatory=$false)]
        [ValidatePattern("^((KB){0,1}[0-9]{1,7})$")]
        [string[]]$ExcludeKbs,

        [Parameter(Mandatory=$false)]
        [ValidatePattern("^(CriticalUpdates|SecurityUpdates|DefinitionUpdates|Drivers|FeaturePacks|ServicePacks|Tools|UpdateRollups|Updates|Application|Connectors|DeveloperKits|Guidance|Microsoft)$")]
        [string[]]$Categories,

        [Parameter(Mandatory=$false)]
        [ValidatePattern("^(Critical|Important|Low|Moderate|Unspecified)$")]
        [string[]]$SeverityLevels,

        [Parameter(Mandatory=$false)]
        [ValidateRange(1,[int]::MaxValue)]
        [int]$PublishedDaysOld,

        [Parameter(Mandatory=$false)]
        [ValidatePattern("^(0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])[- \/.]((?:19|20)\d\d)$")]
        [string]$PublishedDateAfter,

        [Parameter(Mandatory=$false)]
        [ValidatePattern("^(0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])[- \/.]((?:19|20)\d\d)$")]
        [string]$PublishedDateBefore,

        [Parameter(Mandatory=$false)]
        [switch]$ListOnly,

        [Parameter(Mandatory=$false)]
        [switch]$NoReboot,

        [Parameter(Mandatory=$false)]
        [AwsPoshLogger]$Logger
    )

    DynamicParam
    {
        $runtimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary 

        if($Logger -eq $null)
        {
            # made as a dynparam because validationset values are read from a file 
            $parameterName = 'LogLevel'                    
            $parameterAttribute = New-Object System.Management.Automation.parameterAttribute
            $parameterAttribute.Mandatory = $false
            $attributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $attributeCollection.Add($parameterAttribute)
            [string[]]$arrSet = Get-Content "$PSScriptRoot\DynamicParams\LogLevels.txt"
            $validateSetAttribute = New-Object System.Management.Automation.validateSetAttribute($arrSet)
            $attributeCollection.Add($validateSetAttribute)
            $runtimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($parameterName, [string], $attributeCollection)
            $runtimeParameter.Value = "Info"                    
            $runtimeParameterDictionary.Add($parameterName, $runtimeParameter)
        }

        return $runtimeParameterDictionary
    }

    Begin
    {	 
        # Dynamic Paramaters
        $PsBoundParameters.GetEnumerator() | ForEach-Object { New-Variable -Name $_.Key -Value $_.Value -ErrorAction 'SilentlyContinue'}
           
        # We want to treat all errors as terminating so they are caught.
        $temp = $ErrorActionPreference
        $ErrorActionPreference = "Stop"

        $functionName = "Install-AwsUwiWindowsUpdates"
        $moduleName = "AWSUpdateWindowsInstance"
        if(-not ($WorkingDirectory))
        {
            $WorkingDirectory = Join-Path ${env:ProgramData} ("Amazon\$($moduleName)\$($Id)\$($functionName)")
        }
        else
        {
            $WorkingDirectory = Join-Path $WorkingDirectory $functionName
        }

        if(-not (Test-Path $WorkingDirectory))
        {
            New-Item $WorkingDirectory -Type Directory -Force | Out-Null
        }
        
        if($Logger -eq $null)
        {   
            # Set default LogLevel       
            if(-not ($LogLevel))
            {
                $LogLevel = "Info"
            }

            $logFile = Join-Path $WorkingDirectory "$($functionName).log"
            if(-not (Test-Path $logFile))
            {
                New-Item $logFile -type File -Force | Out-Null
            }
                    
            $Logger = New-AwsPoshLogger -LogFile $logFile -LogLevel $LogLevel
        }      
    }

    Process
    {	
        #-------------------------------------------------------------------------------------------------
        #    1 - Create the search string (Includes filtering on Categories)
        #-------------------------------------------------------------------------------------------------
        # Default search string
        $searchString  = "IsHidden=0 and IsInstalled=0" 
        
        # Convert Category Names to Category ID's (UUID's)
        $categoryIds = @()       
        if($Categories)
        {
            $Logger.Info("Filtering on Category. (Pre-Search)")

            if($Categories -contains 'Application'){$categoryIds += '5C9376AB-8CE6-464A-B136-22113DD69801'}
            if($Categories -contains 'Connectors'){$categoryIds += '434DE588-ED14-48F5-8EED-A15E09A991F6'}
            if($Categories -contains 'CriticalUpdates'){$categoryIds += 'E6CF1350-C01B-414D-A61F-263D14D133B4'}
            if($Categories -contains 'DefinitionUpdates'){$categoryIds += 'E0789628-CE08-4437-BE74-2495B842F43B'}
            if($Categories -contains 'DeveloperKits'){$categoryIds += 'E140075D-8433-45C3-AD87-E72345B36078'}
            if($Categories -contains 'Drivers'){$categoryIds += 'EBFC1FC5-71A4-4F7B-9ACA-3B9A503104A0'}                        
            if($Categories -contains 'FeaturePacks'){$categoryIds += 'B54E7D24-7ADD-428F-8B75-90A396FA584F'}
            if($Categories -contains 'Guidance'){$categoryIds += '9511D615-35B2-47BB-927F-F73D8E9260BB'}
            if($Categories -contains 'Microsoft'){$categoryIds += '56309036-4c77-4dd9-951a-99ee9c246a94'}
            if($Categories -contains 'SecurityUpdates'){$categoryIds += '0FA1201D-4330-4FA8-8AE9-B877473B6441'}
            if($Categories -contains 'ServicePacks'){$categoryIds += '68C5B0A3-D1A6-4553-AE49-01D3A7827828'}
            if($Categories -contains 'Tools'){$categoryIds += 'B4832BD8-E735-4761-8DAF-37F882276DAB'}
            if($Categories -contains 'UpdateRollups'){$categoryIds += '28BC880E-0592-4CBF-8F95-C79B17911D5F'}  
            if($Categories -contains 'Updates'){$categoryIds += 'CD5FFD1E-E932-4E3A-BF74-18BF0B1BBD83'}

            if($categoryIds.Count -gt 0)
            {
                $tmp = $searchString
                $searchString = ''
                foreach($categoryId in $categoryIds)
                {
                    [string]$searchString += "($tmp and CategoryIDs contains '$categoryId') or "     
                }

                $searchString = $searchString.TrimEnd(' or ')
            }
        }

        #-------------------------------------------------------------------------------------------------
        #    2 - Search for updates
        #-------------------------------------------------------------------------------------------------
        $updateSession = New-Object -ComObject Microsoft.Update.Session
        $updateSearcher = $updateSession.CreateUpdateSearcher()
    
        $Logger.Info("Searching for Windows Updates.")
        [int]$retryCount = 0
        [int]$retryAttempts = 3
        while($retryCount -lt $retryAttempts)
        {
            try 
            {
                $searchResult = $updateSearcher.Search($searchString)
                $retryCount = $retryAttempts
            } 
            catch
            {    
                $retryCount++

                if($retryCount -eq $retryAttempts)
                {
                    $Logger.Error("Searching for updates resulted in error: $($_)")
                    exit -1	
                }
            }
        }

        $Logger.Info("Found $($searchResult.Updates.count) available Windows Updates.")

        $updatesCollection = New-Object -ComObject Microsoft.Update.UpdateColl
        foreach($update in $searchResult.Updates)
        {
            if ($update.EulaAccepted -eq 0) 
            {
                $update.AcceptEula() 
            }
        
            $updatesCollection.Add($update) | Out-Null 
        }

        #-------------------------------------------------------------------------------------------------
        #    3 - Filter updates
        #-------------------------------------------------------------------------------------------------           
        if($updatesCollection.Count -gt 0)
        {
            if($SeverityLevels)
            {              
                $Logger.Info("Filtering on Severity. (Post-Search)")

                $tempCollection = New-Object -ComObject Microsoft.Update.UpdateColl
                foreach($update in $updatesCollection)
                {
                    if($SeverityLevels -contains $update.MsrcSeverity)
                    {
                        $tempCollection.Add($update) | Out-Null  
                    }

                    # Unspecified if MsrcSeverity has no value 
                    if(-not ($update.MsrcSeverity) -and $SeverityLevels -contains 'Unspecified')
                    {
                        $tempCollection.Add($update) | Out-Null
                    }
                }

                $updatesCollection = $tempCollection
                $Logger.Info("There are $($updatesCollection.Count) Windows Updates after filtering on Severity.")
            }

            if($IncludeKbs)
            {
                $Logger.Info("Filtering on IncludeKbs. (Post-Search)")
        
                # format the list; removing the kb prefix from each string in the list
                # we do this so that our list supports both kb<id> and <id>
                for([int]$i=0; $i -le $IncludeKbs.Length-1; $i++)
                {
                    $IncludeKbs[$i] = $IncludeKbs[$i].ToLower().TrimStart("kb")
                }

                $tempCollection = New-Object -ComObject Microsoft.Update.UpdateColl
                foreach($update in $updatesCollection)
                {
                    if($IncludeKbs -contains $update.KBArticleIDs)
                    {
                        $tempCollection.Add($update) | Out-Null  
                    }
                }

                $updatesCollection = $tempCollection
                $Logger.Info("There are $($updatesCollection.Count) Windows Updates after filtering on IncludeKbs.")
            }

            if($ExcludeKbs)
            {
                $Logger.Info("Filtering on ExcludeKbs. (Post-Search)")

                # format the list; removing the kb prefix from each string in the list
                # we do this so that our list supports both kb<id> and <id>
                for([int]$i=0; $i -le $ExcludeKbs.Length-1; $i++)
                {
                    $ExcludeKbs[$i] = $ExcludeKbs[$i].ToLower().TrimStart("kb")
                }

                $tempCollection = New-Object -ComObject Microsoft.Update.UpdateColl
                foreach($update in $updatesCollection)
                {
                    # remove kb's if they are not in the include list
                    if($ExcludeKbs -notcontains $update.KBArticleIDs)
                    {
                        $tempCollection.Add($update) | Out-Null
                    }
                }

                $updatesCollection = $tempCollection
                $Logger.Info("There are $($updatesCollection.Count) Windows Updates after filtering on ExcludeKbs.")
            }

            if($PublishedDaysOld -gt 0)
            {
                $Logger.Info("Filtering on PublishedDaysOld. (Post-Search)")

                $tempCollection = New-Object -ComObject Microsoft.Update.UpdateColl
                $dateNow = (Get-Date).ToUniversalTime()
                foreach($update in $updatesCollection)
                {
                    $updateAge = (New-TimeSpan -Start $update.LastDeploymentChangeTime -End $dateNow).Days
                    if($updateAge -ge $PublishedDaysOld)
                    {
                        $tempCollection.Add($update) | Out-Null  
                    }
                }

                $updatesCollection = $tempCollection
                $Logger.Info("There are $($updatesCollection.Count) Windows Updates after filtering on PublishedDaysOld.")
            }

            if($PublishedDateAfter)
            {
                $Logger.Info("Filtering on PublishedDateAfter. (Post-Search)")

                $tempCollection = New-Object -ComObject Microsoft.Update.UpdateColl
                foreach($update in $updatesCollection)
                {
                    $days = (New-TimeSpan -Start ([DateTime]$PublishedDateAfter) -End $update.LastDeploymentChangeTime).Days
                    if($days -ge 0)
                    {
                        $tempCollection.Add($update) | Out-Null  
                    }
                }

                $updatesCollection = $tempCollection
                $Logger.Info("There are $($updatesCollection.Count) Windows Updates after filtering on PublishedDateAfter.")
            }
        
            if($PublishedDateBefore)
            {
                $Logger.Info("Filtering on PublishedDateBefore. (Post-Search)")

                $tempCollection = New-Object -ComObject Microsoft.Update.UpdateColl
                foreach($update in $updatesCollection)
                {
                    $days = (New-TimeSpan -Start ([DateTime]$PublishedDateBefore) -End $update.LastDeploymentChangeTime).Days
                    if($days -le 0)
                    {
                        $tempCollection.Add($update) | Out-Null  
                    }
                }

                $updatesCollection = $tempCollection
                $Logger.Info("There are $($updatesCollection.Count) Windows Updates after filtering on PublishedDateAfter.")
            }
        }

        # Log all the updates in the collection after filtering
        foreach($update in $updatesCollection)
        {
            $Logger.Info("$($update.Title) - Published date: $($update.LastDeploymentChangeTime.ToString("MM/dd/yyyy"))")     
        }
        
        if(-not ($ListOnly))
        {
            #-------------------------------------------------------------------------------------------------
            #	Step 4: Download updates
            #-------------------------------------------------------------------------------------------------
            $downloadedCollection = New-Object -ComObject "Microsoft.Update.UpdateColl"
            if($updatesCollection.Count -gt 0)
            {
                $Logger.Info("Downloading Windows Updates.")
                [int]$downloadErrors = 0
                foreach($update in $updatesCollection)
                {
                    if($update.IsDownloaded -ne $true)
                    {
                        $tempCollection = New-Object -ComObject "Microsoft.Update.UpdateColl"
                        $tempCollection.Add($update) | Out-Null
                        $downloader = $updateSession.CreateUpdateDownloader()
                        $downloader.Updates = $tempCollection

                        $retryCount = 0
                        while($retryCount -lt $retryAttempts)
                        {
                            try
                            {
                                $downloader.Download() | Out-Null
                                $downloadedCollection.Add($update) | Out-Null
                                $Logger.Info("Successfully Downloaded: $($update.Title) - Published date: $($update.LastDeploymentChangeTime.ToString("MM/dd/yyyy"))")
                                $retryCount = $retryAttempts                    
                            }
                            catch
                            {
                                $retryCount++
                                
                                if($retryCount -eq $retryAttempts)
                                {
                                    $Logger.Error("Downloading $($update.Title) resulted in error: $($_)")
                                    $downloadErrors++
                                }
                            }
                        }
                    }
                    else
                    {           
                        $downloadedCollection.Add($update) | Out-Null
                        $Logger.Info("Successfully Downloaded: $($update.Title)")
                    }
                }

                $Logger.Info("$($downloadedCollection.Count) Windows Updates will be installed.")
            }
        
            #-------------------------------------------------------------------------------------------------
            #	Step 5: Install updates
            #-------------------------------------------------------------------------------------------------   
            $installedKbs = @()
            if($downloadedCollection.Count -gt 0)
            {
                [int]$installErrors = 0
                [bool]$installedUpdates = $false
                foreach($update in $downloadedCollection) 
                {
                    if($update.IsInstalled -ne $true)
                    {
                        $tempUpdatesCollection = New-Object -ComObject "Microsoft.Update.UpdateColl"
                        $tempUpdatesCollection.Add($update) | Out-Null
                        $updatesInstaller = $updateSession.CreateUpdateInstaller()
                        $updatesInstaller.Updates = $tempUpdatesCollection
                        
                        try 
                        {
                            $installObj = $updatesInstaller.Install() | Out-Null
                            $installedUpdates = $true
                            [string]$message = "Installed: $($update.Title)"
                            if($installObj.RebootRequired -eq $true)
                            {
                                $message += " [Reboot Required]"
                            }

                            $Logger.Info($message)
                        } 
                        catch
                        {
                            $Logger.Error("Installation of $($update.Title) resulted in error: $($_)")
                            $installErrors++
                        }
                    }
                
                    # Create an object to hold the data of what update was installed to be used in the state file
                    $hash = Get-StringHash "$($update.Title)$($update.KBArticleIDs)"
                    $properties = @{Title=$update.Title;KBArticleIDs=$update.KBArticleIDs;Hash=$hash;}
                    $installedKbs += New-Object -TypeName PSObject -Property $properties                    
                }
            }

            #-------------------------------------------------------------------------------------------------
            #    Step 6: - Fail if any download or installation errors occurred
            #------------------------------------------------------------------------------------------------- 
            if(($downloadErrors + $installErrors) -gt 0)
            {
                $Logger.Info("$($downloadErrors.ToString()) download and $($installErrors.ToString()) installation errors occurred.")
                exit -1
            }

            #-------------------------------------------------------------------------------------------------
            #    Step 7: - If there was an attempt to install the same KB, it will exit with a failure.
            #------------------------------------------------------------------------------------------------- 
            if($installedKbs)
            {
                $stateFile = Join-Path $WorkingDirectory 'state.json'
                $stateFileObjs = @()
                if(Test-Path $stateFile)
                {
                    try
                    {
                        $stateFileObjs = Get-Content -Path $stateFile -Raw | ConvertFrom-Json
                    }
                    catch
                    {
                        $Logger.Error("Attempt to read state file resulted in error: $($_)")
                        exit -1
                    }
                }
                
                foreach($installedKb in $installedKbs)
                {
                    $match = $stateFileObjs | Where-Object {$_.Hash -eq $installedKb.Hash}
                    if($match)
                    {
                        $Logger.Error("Multiple attempts to install the same KB failed: $($installedKb.Title)")
                        exit -1   
                    }
                    else
                    {
                        $stateFileObjs += $installedKb
                    }
                }

                try
                {
                    $stateFileObjs | ConvertTo-Json | Out-File $stateFile -Force
                }
                catch
                {
                    $Logger.Error("Writing state file resulted in error: $($_)")
                    exit -1 
                }
            }

            #-------------------------------------------------------------------------------------------------
            #    Step 8: - Perform a reboot if any updates were installed.
            #-------------------------------------------------------------------------------------------------         
            if($installedUpdates -and (-not $NoReboot))
            {
                $Logger.Info("Windows Updates were successfully installed. Rebooting.")
                exit 3010
            }            
        }
    }
    End
    {
        $ErrorActionPreference = $temp
    }
}
# SIG # Begin signature block
# MIIePAYJKoZIhvcNAQcCoIIeLTCCHikCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCdSritLHu6pnPA
# ccODuoxa2K/qNIzBv/s0QmhMqaJiWaCCDJwwggXYMIIEwKADAgECAhABVznfx2xi
# Vuf0Y3KCrPFgMA0GCSqGSIb3DQEBCwUAMGwxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xKzApBgNV
# BAMTIkRpZ2lDZXJ0IEVWIENvZGUgU2lnbmluZyBDQSAoU0hBMikwHhcNMTcwNjAx
# MDAwMDAwWhcNMjAwNjA0MTIwMDAwWjCCAR0xHTAbBgNVBA8MFFByaXZhdGUgT3Jn
# YW5pemF0aW9uMRMwEQYLKwYBBAGCNzwCAQMTAlVTMRkwFwYLKwYBBAGCNzwCAQIT
# CERlbGF3YXJlMRAwDgYDVQQFEwc0MTUyOTU0MRgwFgYDVQQJEw80MTAgVGVycnkg
# QXZlIE4xDjAMBgNVBBETBTk4MTA5MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHU2VhdHRsZTEiMCAGA1UEChMZQW1hem9uIFdlYiBT
# ZXJ2aWNlcywgSW5jLjEUMBIGA1UECxMLRUMyIFdpbmRvd3MxIjAgBgNVBAMTGUFt
# YXpvbiBXZWIgU2VydmljZXMsIEluYy4wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAw
# ggEKAoIBAQDIcVfNSR3j5LoUqVUMtxS4NIJq/qOGQMGnTz95nmtpLOG8nv47GzUx
# zFkqnFmDxxjV9LUoMd5yZhVWyfEIMv7RsV0RhMZqJ/rutNfwt3r/4htqxDqiUHwN
# UKtqoHOw0Q2qSyKFbawCUbm/Bf3r/ya5ACbEz/abzCivvJsvQoRtflyfCemwF2Qu
# K8aw5c98Ab9xl0/ZJgd+966Bvxjf2VVKWf5pOuQKNo6ncZOU9gtgk8uV8h5yIttF
# sJP7KpN/hoXZC88EZXzjizSuLhutd7TEzBY56Lf9q0giZ+R8iiYQdenkKBGp75uv
# UqbJV+hjndohgKRZ8EnWQFVvVm2raAZTAgMBAAGjggHBMIIBvTAfBgNVHSMEGDAW
# gBSP6H7wbTJqAAUjx3CXajqQ/2vq1DAdBgNVHQ4EFgQUpJ202cGjSh7SNUwws5w6
# QmE9IYUwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMHsGA1Ud
# HwR0MHIwN6A1oDOGMWh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9FVkNvZGVTaWdu
# aW5nU0hBMi1nMS5jcmwwN6A1oDOGMWh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9F
# VkNvZGVTaWduaW5nU0hBMi1nMS5jcmwwSwYDVR0gBEQwQjA3BglghkgBhv1sAwIw
# KjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzAHBgVn
# gQwBAzB+BggrBgEFBQcBAQRyMHAwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRp
# Z2ljZXJ0LmNvbTBIBggrBgEFBQcwAoY8aHR0cDovL2NhY2VydHMuZGlnaWNlcnQu
# Y29tL0RpZ2lDZXJ0RVZDb2RlU2lnbmluZ0NBLVNIQTIuY3J0MAwGA1UdEwEB/wQC
# MAAwDQYJKoZIhvcNAQELBQADggEBAATn4LxNeqlebC8j+gebBiwGYYbc8mM+5NUp
# me5SdJHXsOQptpl9jnZFboEVDltnxfHEMtebLGqX5kz7weqt5HpWatcjvMTTbZrq
# OMTVvsrNgcSjJ/VZoaWqmFsu4uHuwHXCHyqFUA5BxSqJrMjLLYNh5SE/Z8jQ2BAY
# nZhahetnz7Od2IoJzNgRqSHM/OXsZrTKsxv+o8qPqUKwhu+5HFHS+fXXvv5iZ9MO
# LcKTPZYecojbgdZCk+qCYuhyThSR3AUdlRAHHnJyMckNUitEiRNQtxXZ8Su1yBF5
# BExMdUEFAGCHyXq3zUg5g+6Ou53VYmGMJNTIDh77kp10b8usIB4wgga8MIIFpKAD
# AgECAhAD8bThXzqC8RSWeLPX2EdcMA0GCSqGSIb3DQEBCwUAMGwxCzAJBgNVBAYT
# AlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2Vy
# dC5jb20xKzApBgNVBAMTIkRpZ2lDZXJ0IEhpZ2ggQXNzdXJhbmNlIEVWIFJvb3Qg
# Q0EwHhcNMTIwNDE4MTIwMDAwWhcNMjcwNDE4MTIwMDAwWjBsMQswCQYDVQQGEwJV
# UzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQu
# Y29tMSswKQYDVQQDEyJEaWdpQ2VydCBFViBDb2RlIFNpZ25pbmcgQ0EgKFNIQTIp
# MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAp1P6D7K1E/Fkz4SA/K6A
# NdG218ejLKwaLKzxhKw6NRI6kpG6V+TEyfMvqEg8t9Zu3JciulF5Ya9DLw23m7RJ
# Ma5EWD6koZanh08jfsNsZSSQVT6hyiN8xULpxHpiRZt93mN0y55jJfiEmpqtRU+u
# fR/IE8t1m8nh4Yr4CwyY9Mo+0EWqeh6lWJM2NL4rLisxWGa0MhCfnfBSoe/oPtN2
# 8kBa3PpqPRtLrXawjFzuNrqD6jCoTN7xCypYQYiuAImrA9EWgiAiduteVDgSYuHS
# cCTb7R9w0mQJgC3itp3OH/K7IfNs29izGXuKUJ/v7DYKXJq3StMIoDl5/d2/PToJ
# JQIDAQABo4IDWDCCA1QwEgYDVR0TAQH/BAgwBgEB/wIBADAOBgNVHQ8BAf8EBAMC
# AYYwEwYDVR0lBAwwCgYIKwYBBQUHAwMwfwYIKwYBBQUHAQEEczBxMCQGCCsGAQUF
# BzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wSQYIKwYBBQUHMAKGPWh0dHA6
# Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEhpZ2hBc3N1cmFuY2VFVlJv
# b3RDQS5jcnQwgY8GA1UdHwSBhzCBhDBAoD6gPIY6aHR0cDovL2NybDMuZGlnaWNl
# cnQuY29tL0RpZ2lDZXJ0SGlnaEFzc3VyYW5jZUVWUm9vdENBLmNybDBAoD6gPIY6
# aHR0cDovL2NybDQuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0SGlnaEFzc3VyYW5jZUVW
# Um9vdENBLmNybDCCAcQGA1UdIASCAbswggG3MIIBswYJYIZIAYb9bAMCMIIBpDA6
# BggrBgEFBQcCARYuaHR0cDovL3d3dy5kaWdpY2VydC5jb20vc3NsLWNwcy1yZXBv
# c2l0b3J5Lmh0bTCCAWQGCCsGAQUFBwICMIIBVh6CAVIAQQBuAHkAIAB1AHMAZQAg
# AG8AZgAgAHQAaABpAHMAIABDAGUAcgB0AGkAZgBpAGMAYQB0AGUAIABjAG8AbgBz
# AHQAaQB0AHUAdABlAHMAIABhAGMAYwBlAHAAdABhAG4AYwBlACAAbwBmACAAdABo
# AGUAIABEAGkAZwBpAEMAZQByAHQAIABDAFAALwBDAFAAUwAgAGEAbgBkACAAdABo
# AGUAIABSAGUAbAB5AGkAbgBnACAAUABhAHIAdAB5ACAAQQBnAHIAZQBlAG0AZQBu
# AHQAIAB3AGgAaQBjAGgAIABsAGkAbQBpAHQAIABsAGkAYQBiAGkAbABpAHQAeQAg
# AGEAbgBkACAAYQByAGUAIABpAG4AYwBvAHIAcABvAHIAYQB0AGUAZAAgAGgAZQBy
# AGUAaQBuACAAYgB5ACAAcgBlAGYAZQByAGUAbgBjAGUALjAdBgNVHQ4EFgQUj+h+
# 8G0yagAFI8dwl2o6kP9r6tQwHwYDVR0jBBgwFoAUsT7DaQP4v0cB1JgmGggC72Nk
# K8MwDQYJKoZIhvcNAQELBQADggEBABkzSgyBMzfbrTbJ5Mk6u7UbLnqi4vRDQhee
# v06hTeGx2+mB3Z8B8uSI1en+Cf0hwexdgNLw1sFDwv53K9v515EzzmzVshk75i7W
# yZNPiECOzeH1fvEPxllWcujrakG9HNVG1XxJymY4FcG/4JFwd4fcyY0xyQwpojPt
# jeKHzYmNPxv/1eAal4t82m37qMayOmZrewGzzdimNOwSAauVWKXEU1eoYObnAhKg
# uSNkok27fIElZCG+z+5CGEOXu6U3Bq9N/yalTWFL7EZBuGXOuHmeCJYLgYyKO4/H
# mYyjKm6YbV5hxpa3irlhLZO46w4EQ9f1/qbwYtSZaqXBwfBklIAxghD2MIIQ8gIB
# ATCBgDBsMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMSswKQYDVQQDEyJEaWdpQ2VydCBFViBDb2Rl
# IFNpZ25pbmcgQ0EgKFNIQTIpAhABVznfx2xiVuf0Y3KCrPFgMA0GCWCGSAFlAwQC
# AQUAoHwwEAYKKwYBBAGCNwIBDDECMAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIE
# IBX/0PUFb34p2xGQ6qdQ86+Hw6rwg8L5rtTFE71HB8xIMA0GCSqGSIb3DQEBAQUA
# BIIBAG4lOZNKNLNjE/6Oz1NsHUaVWMflnoFiUajE2iEkcLwCeHj/k5R2Hqv941Y5
# +e+OxB6XflItXwiprsGDNmHpBEwdr6gaETCj8HiThEFsojveSmi+cTnCeB00Le/d
# 1M5cW41tV/y9lHdbOg4e84knT8t2uVSbqe0NlSyIaHY7qPyqkElWuLjemTor0Pop
# jPuGmZ+osbGDxyIbiWAiQn9f9G6CpLVeOeYW0eCMPaZgRCJBoZCup/ouYVUYp7n9
# 0D2RZa+CZP8FdF9OPFfcXFcRghNfHGx80YCIPsKA367sR27fL78tNpgUAeH7Tg3A
# w7odDTTaWVjBpjKZgcS18B0Jgmmhgg7IMIIOxAYKKwYBBAGCNwMDATGCDrQwgg6w
# BgkqhkiG9w0BBwKggg6hMIIOnQIBAzEPMA0GCWCGSAFlAwQCAQUAMHcGCyqGSIb3
# DQEJEAEEoGgEZjBkAgEBBglghkgBhv1sBwEwMTANBglghkgBZQMEAgEFAAQgpBYi
# lZJ4ladMcK7V/B8USQHpiysMTZRb3r2jD7SQ740CEFNbLGitWHoUrx72Q6fhC48Y
# DzIwMTgxMDI0MTcxODAxWqCCC7swggaCMIIFaqADAgECAhAJwPxGyARCE7VZi68o
# T05BMA0GCSqGSIb3DQEBCwUAMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdp
# Q2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERp
# Z2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBUaW1lc3RhbXBpbmcgQ0EwHhcNMTcwMTA0
# MDAwMDAwWhcNMjgwMTE4MDAwMDAwWjBMMQswCQYDVQQGEwJVUzERMA8GA1UEChMI
# RGlnaUNlcnQxKjAoBgNVBAMTIURpZ2lDZXJ0IFNIQTIgVGltZXN0YW1wIFJlc3Bv
# bmRlcjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJ6VmGo0O3MbqH78
# x74paYnHaCZGXz2NYnOHgaOhnPC3WyQ3WpLU9FnXdonk3NUn8NVmvArutCsxZ6xY
# xUqRWStFHgkB1mSzWe6NZk37I17MEA0LimfvUq6gCJDCUvf1qLVumyx7nee1Pvt4
# zTJQGL9AtUyMu1f0oE8RRWxCQrnlr9bf9Kd8CmiWD9JfKVfO+x0y//QRoRMi+xLL
# 79dT0uuXy6KsGx2dWCFRgsLC3uorPywihNBD7Ds7P0fE9lbcRTeYtGt0tVmveFdp
# yA8JAnjd2FPBmdtgxJ3qrq/gfoZKXKlYYahedIoBKGhyTqeGnbUCUodwZkjTju+B
# JMzc2GUCAwEAAaOCAzgwggM0MA4GA1UdDwEB/wQEAwIHgDAMBgNVHRMBAf8EAjAA
# MBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMIIBvwYDVR0gBIIBtjCCAbIwggGhBglg
# hkgBhv1sBwEwggGSMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdpY2VydC5j
# b20vQ1BTMIIBZAYIKwYBBQUHAgIwggFWHoIBUgBBAG4AeQAgAHUAcwBlACAAbwBm
# ACAAdABoAGkAcwAgAEMAZQByAHQAaQBmAGkAYwBhAHQAZQAgAGMAbwBuAHMAdABp
# AHQAdQB0AGUAcwAgAGEAYwBjAGUAcAB0AGEAbgBjAGUAIABvAGYAIAB0AGgAZQAg
# AEQAaQBnAGkAQwBlAHIAdAAgAEMAUAAvAEMAUABTACAAYQBuAGQAIAB0AGgAZQAg
# AFIAZQBsAHkAaQBuAGcAIABQAGEAcgB0AHkAIABBAGcAcgBlAGUAbQBlAG4AdAAg
# AHcAaABpAGMAaAAgAGwAaQBtAGkAdAAgAGwAaQBhAGIAaQBsAGkAdAB5ACAAYQBu
# AGQAIABhAHIAZQAgAGkAbgBjAG8AcgBwAG8AcgBhAHQAZQBkACAAaABlAHIAZQBp
# AG4AIABiAHkAIAByAGUAZgBlAHIAZQBuAGMAZQAuMAsGCWCGSAGG/WwDFTAfBgNV
# HSMEGDAWgBT0tuEgHf4prtLkYaWyoiWyyBc1bjAdBgNVHQ4EFgQU4acySu4BISh9
# VNXyB5JutAcPPYcwcQYDVR0fBGowaDAyoDCgLoYsaHR0cDovL2NybDMuZGlnaWNl
# cnQuY29tL3NoYTItYXNzdXJlZC10cy5jcmwwMqAwoC6GLGh0dHA6Ly9jcmw0LmRp
# Z2ljZXJ0LmNvbS9zaGEyLWFzc3VyZWQtdHMuY3JsMIGFBggrBgEFBQcBAQR5MHcw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBPBggrBgEFBQcw
# AoZDaHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0U0hBMkFzc3Vy
# ZWRJRFRpbWVzdGFtcGluZ0NBLmNydDANBgkqhkiG9w0BAQsFAAOCAQEAHvBBgjKu
# 7fG0NRPcUMLVl64iIp0ODq8z00z9fL9vARGnlGUiXMYiociJUmuajHNc2V4/Mt4W
# YEyLNv0xmQq9wYS3jR3viSYTBVbzR81HW62EsjivaiO1ReMeiDJGgNK3ppki/cF4
# z/WL2AyMBQnuROaA1W1wzJ9THifdKkje2pNlrW5lo5mnwkAOc8xYT49FKOW8nIjm
# KM5gXS0lXYtzLqUNW1Hamk7/UAWJKNryeLvSWHiNRKesOgCReGmJZATTXZbfKr/5
# pUwsk//mit2CrPHSs6KGmsFViVZqRz/61jOVQzWJBXhaOmnaIrgEQ9NvaDU2ehQ+
# RemYZIYPEwwmSjCCBTEwggQZoAMCAQICEAqhJdbWMht+QeQF2jaXwhUwDQYJKoZI
# hvcNAQELBQAwZTELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZ
# MBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNz
# dXJlZCBJRCBSb290IENBMB4XDTE2MDEwNzEyMDAwMFoXDTMxMDEwNzEyMDAwMFow
# cjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQ
# d3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVk
# IElEIFRpbWVzdGFtcGluZyBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC
# ggEBAL3QMu5LzY9/3am6gpnFOVQoV7YjSsQOB0UzURB90Pl9TWh+57ag9I2ziOSX
# v2MhkJi/E7xX08PhfgjWahQAOPcuHjvuzKb2Mln+X2U/4Jvr40ZHBhpVfgsnfsCi
# 9aDg3iI/Dv9+lfvzo7oiPhisEeTwmQNtO4V8CdPuXciaC1TjqAlxa+DPIhAPdc9x
# ck4Krd9AOly3UeGheRTGTSQjMF287DxgaqwvB8z98OpH2YhQXv1mblZhJymJhFHm
# gudGUP2UKiyn5HU+upgPhH+fMRTWrdXyZMt7HgXQhBlyF/EXBu89zdZN7wZC/aJT
# Kk+FHcQdPK/P2qwQ9d2srOlW/5MCAwEAAaOCAc4wggHKMB0GA1UdDgQWBBT0tuEg
# Hf4prtLkYaWyoiWyyBc1bjAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823I
# DzASBgNVHRMBAf8ECDAGAQH/AgEAMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAK
# BggrBgEFBQcDCDB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9v
# Y3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMuZGln
# aWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNydDCBgQYDVR0fBHow
# eDA6oDigNoY0aHR0cDovL2NybDQuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJl
# ZElEUm9vdENBLmNybDA6oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0Rp
# Z2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDBQBgNVHSAESTBHMDgGCmCGSAGG/WwA
# AgQwKjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzAL
# BglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggEBAHGVEulRh1Zpze/d2nyqY3qz
# eM8GN0CE70uEv8rPAwL9xafDDiBCLK938ysfDCFaKrcFNB1qrpn4J6JmvwmqYN92
# pDqTD/iy0dh8GWLoXoIlHsS6HHssIeLWWywUNUMEaLLbdQLgcseY1jxk5R9IEBhf
# iThhTWJGJIdjjJFSLK8pieV4H9YLFKWA1xJHcLN11ZOFk362kmf7U2GJqPVrlsD0
# WGkNfMgBsbkodbeZY4UijGHKeZR+WfyMD+NvtQEmtmyl7odRIeRYYJu6DC0rbaLE
# frvEJStHAgh8Sa4TtuF8QkIoxhhWz0E0tmZdtnR79VYzIi8iNrJLokqV2PWmjlIx
# ggJNMIICSQIBATCBhjByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQg
# SW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2Vy
# dCBTSEEyIEFzc3VyZWQgSUQgVGltZXN0YW1waW5nIENBAhAJwPxGyARCE7VZi68o
# T05BMA0GCWCGSAFlAwQCAQUAoIGYMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRAB
# BDAcBgkqhkiG9w0BCQUxDxcNMTgxMDI0MTcxODAxWjAvBgkqhkiG9w0BCQQxIgQg
# CmJ0aUSOrsvOtHLbAVXeVTVr7Nz4fiQ2246YYlf8mrAwKwYLKoZIhvcNAQkQAgwx
# HDAaMBgwFgQUQAGRR1yYiR3roQSvRwkbXrbUy8swDQYJKoZIhvcNAQEBBQAEggEA
# kIx73Ky2zqRN8opyH7aUT5NJ5Y81m18beVNe97ocSpEXn+1qzPJ3Atk7AiNmO8JT
# Pcpfo+xcPGTpAlUJrD7xn8Ju/qxJZVLhpjxFir9068b7nDq8AQTlaJ6Blt2Mg5Bg
# DsniViPJxBhwK8tIz+I9hwW4Ub1rGXBZKP+E1ox2dsDHwBc/2Vl661/LWHFN0Xd7
# 3ENJU+KoIgqB5YpI4beH5HUnvHfONMPoP+Jjh+/36weK7/m9iK7u/zpIlkgAoRjZ
# hnNikuGzavMuQ3K191+M0kbGYk9H9a2WRA5Cyg1CQ1rGYiQvCXVxPXnOkLG1cI/G
# 70Pw7jrFgpUIAjJwQ8jJ0A==
# SIG # End signature block
