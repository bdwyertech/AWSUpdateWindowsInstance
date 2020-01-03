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

Function Start-AwsUwiSysprep
{
    <#
        .SYNOPSIS
        Performs sysprep on the instance.
                
        .DESCRIPTION
        Performs sysprep.  It also enables password generation.

        .PARAMETER Id
        An ID for the execution of this cmdlet.  Default ID will be a random GUID.

        .PARAMETER Logger
        This logger object is responsible for writing logs.  The logger is of type AWSPoshLogger.

        .EXAMPLE
        Start-AwsUwiSysprep

        .EXAMPLE
        Start-AwsUwiSysprep

        .EXAMPLE
        Start-AwsUwiSysprep -Id abc123

        .EXAMPLE
        Start-AwsUwiSysprep -Id abc123 -Logger $Logger
    #>

    [CmdletBinding()]
    
    Param 
    (
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$Id = [guid]::NewGuid(),

        [Parameter(Mandatory=$false)]
        [switch]$Shutdown,

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
        $PsBoundParameters.GetEnumerator() | ForEach-Object { New-Variable -Name $_.Key -Value $_.Value -ea 'SilentlyContinue'}
           
        # We want to treat all errors as terminating so they are caught.
        $temp = $ErrorActionPreference
        $ErrorActionPreference = "Stop"

        $functionName = "Start-AwsUwiSysprep"
        $moduleName = "AWSUpdateWindowsInstance"

        if($Logger -eq $null)
        {
            $WorkingDirectory = Join-Path ${env:ProgramData} ("Amazon\$($moduleName)\$($Id)\$($functionName)")
            if(-not (Test-Path $WorkingDirectory))
            {
                New-Item $WorkingDirectory -Type Directory -Force | Out-Null
            }
        
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
        #	Step 1: Create the state file
        #-------------------------------------------------------------------------------------------------
        $stateFile = Join-Path $WorkingDirectory "state_$($functionName).txt"
        if(-not (Test-Path $stateFile))
        {
            # Create and init the state object
            New-Item $stateFile -type File -Force | Out-Null
            $stateObj = New-Object psobject -Property @{Sysprep = 0;}
            ConvertTo-Json -InputObject $stateObj | Out-File $stateFile
        }

        $stateObj = Get-Content $stateFile -Raw | ConvertFrom-Json
        if($stateObj.Sysprep -eq "0")
        {
            $Logger.Info("Start of $($functionName)")
            
            #-------------------------------------------------------------------------------------------------
            #    Step 2: - Detect which launch agent is installed.
            #-------------------------------------------------------------------------------------------------
            try 
            {
                $launchAgent = Start-DetectLaunchAgent
            }
            catch
            {
                $Logger.Error("Detecting the launch agent resulted in error: $($_)")
            }

            #-------------------------------------------------------------------------------------------------
            #    Step 3: - Run Sysprep
            #-------------------------------------------------------------------------------------------------
            try 
            {
                if($launchAgent.LaunchAgentName -eq 'EC2Launch')
                {
                    $Logger.Info("Starting EC2Launch method of sysprep.")
                    Start-EC2LaunchSysprep -WorkingDirectory $WorkingDirectory
                    $Logger.Info("Successfully executed EC2Launch method of sysprep.")
                }

                if($launchAgent.LaunchAgentName -eq 'EC2Config')
                {
                    $Logger.Info("Starting EC2Config method of sysprep.")
                    Start-EC2ConfigSysprep -WorkingDirectory $WorkingDirectory
                    $Logger.Info("Successfully executed EC2Config method of sysprep.")
                }  
            }
            catch 
            {
                $Logger.Error("Sysprep failed with error: $($_)")
                exit -1   
            }

            $stateObj.Sysprep = 1
            ConvertTo-Json -InputObject $stateObj | Out-File $stateFile
        }
        else 
        {
            $Logger.Info("Sysprep was previously performed.")
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
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBVJQWQrw1f0Ox0
# SeXEbMo/2yb0jpGRgqsmVD0vC/73GqCCDJwwggXYMIIEwKADAgECAhABVznfx2xi
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
# INKu6CW66hK6VH5fKcZIUCE/9GLGqnYQgHf8tHuIJQefMA0GCSqGSIb3DQEBAQUA
# BIIBAJTy/cvGF+86YtPNpqIU3c6TJx3PINo8YfnACwJEa24hAVukDGMCTAE+JxdQ
# B4cZxrZQqAv5F24AX6ngqNvrYbWAmh+eGlHL1zAvnjYMFYqbo8CFdUzl1HZKw3BS
# ntydbhhlHi8ZkBEsaKNOuLXveDfjLc3Xvv2LzNFhiVJvIAm7X0OIQWWAVfB9K4bI
# Y0MPkWWpaFjE5Jn6bb/ZZVY00H9QGV0SjwIsOjoCyqEpdVz1zhuemowLeCj7+LK6
# gF2tAFosKzFahnYCs+cjueW1Y2U4c1l3BSaHWJFZTM5vHyKNhz/A/ormfmSqNZTV
# 8VGotpFckvIKdjeh03zh2X14KSehgg7IMIIOxAYKKwYBBAGCNwMDATGCDrQwgg6w
# BgkqhkiG9w0BBwKggg6hMIIOnQIBAzEPMA0GCWCGSAFlAwQCAQUAMHcGCyqGSIb3
# DQEJEAEEoGgEZjBkAgEBBglghkgBhv1sBwEwMTANBglghkgBZQMEAgEFAAQgM6nt
# WDWwT1zmTtrZxzllZe7AZpGIWATZWHSynXDbViQCEFI/GFzA1ZIa/3Raa7s7pk0Y
# DzIwMTgwNTMxMTk1NDMzWqCCC7swggaCMIIFaqADAgECAhAJwPxGyARCE7VZi68o
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
# BDAcBgkqhkiG9w0BCQUxDxcNMTgwNTMxMTk1NDMzWjAvBgkqhkiG9w0BCQQxIgQg
# jjY5qvYs+w4vk+1v7c2nYjwpttp70R7+sMwoo4PS9n0wKwYLKoZIhvcNAQkQAgwx
# HDAaMBgwFgQUQAGRR1yYiR3roQSvRwkbXrbUy8swDQYJKoZIhvcNAQEBBQAEggEA
# iIK8fWaAo1BesS+zHR/3MZBHu5VSC8ep9z7o7gNmqIcxOPh2fBBYJ4R4X+fsiMif
# 3MXNbHRLCqzJ6YYQ7zZ0+HX55puBZ6ilfCKJcMbOPXasppbPOPrWcSog1vdxRXyG
# vs52+VoZLPTlvJvYqzTz8V8+lE+ORHKlxkTsuyDHh6aOCRAeAwqe7CLQV+Anmez5
# 2fZezCWzBT4N/EFCw4AlZW6OwS75gBDnUKc4OTILYuFvypc9I05gyC/7SAe/awxA
# a0Q6mg+L/i4LYopozSyP7tS9xn4GuF/JDba87EhtkaZbId9OZsAmFzIv/qsRr5Nb
# xkOl9WyOAW71bqipSg7IZg==
# SIG # End signature block
