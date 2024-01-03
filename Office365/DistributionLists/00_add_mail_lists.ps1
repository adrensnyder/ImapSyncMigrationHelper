###################################################################
# Copyright (c) 2023 AdrenSnyder https://github.com/adrensnyder
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# DISCLAIMER:
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
###################################################################

$alias_suffix = "_distributionlist"

# Program

$file_arg = $args[0]

if ( [string]::IsNullOrEmpty($file_arg) )  {
    Write-Host "Insert the file with the rules as a parameter" -ForegroundColor Red
    exit
}

Write-Host "Check that the file $file_arg has been saved in UTF-8 format"
Pause

$directory = Split-Path -Path $args[0] -Parent
if (-not $directory ) {
        $file_arg = $PSScriptRoot + "\" + $file_arg
} elseif ( $directory -eq "." ) {
    $file_arg = $file_arg -replace '^\.\\', ''
    $file_arg = $PSScriptRoot + "\" + $file_arg
}

if (-not (Test-Path "$file_arg")) {
    Write-Host "The file $file_arg not exist. Must be in the same folder of this script. Use only the filename as parameter"
    exit
}

$listname_prev = ""

Import-Csv -Path $file_arg | ForEach-Object {
	
    $listname = $($_.List)
    $listname_nodomain = $listname.Split('@')[0]
    $alias = $listname_nodomain + $alias_suffix
    $account = $($_.Account)

    if ($listname -ne $listname_prev) {
        Write-Host ""
        Write-Host -ForegroundColor Green "- Adding members for list $listname"
    }

    $DistributionGroup = Get-DistributionGroup -ResultSize Unlimited | Where-Object { $_.PrimarySmtpAddress -eq $listname }
    
    if (-not $DistributionGroup) {
        Write-Host "The Distribution List will be created!"
        New-DistributionGroup -RequireSenderAuthenticationEnabled $False -DisplayName $listname -Name $listname -PrimarySmtpAddress $listname -Alias $listname_nodomain
        $DistributionGroup = Get-DistributionGroup -ResultSize Unlimited | Where-Object { $_.PrimarySmtpAddress -eq $listname }
    }

    if ($DistributionGroup) {
        Write-Host "Adding mail $account to the Distribution List"
        try{
            Add-DistributionGroupMember -Identity $listname -Member $($_.Account)
        }catch{
            Write-Host "[$listname] Errors adding $account" -ForegroundColor Red
        }
    } else {
        Write-Host -ForegroundColor Red "The Distribution List not exist!"
    }

    $listname_prev = $listname
    
}