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

$mailbox_arg = $args[0]
$file_arg = $args[1]
$listname = "$mailbox_arg"
$listname_nodomain = $listname.Split('@')[0]
$alias = $listname_nodomain + "_listadistribuzione"

Write-Host "- List $listname" -ForegroundColor Green

$DistributionGroup = Get-DistributionGroup -ResultSize Unlimited | Where-Object { $_.PrimarySmtpAddress -eq $listname }

if ($distributionList -ne $null) {
    Write-Host "The Distribution List $mailbox_arg already exists!"
} else {
    Write-Host "The Distribution List will be created!"
    New-DistributionGroup -RequireSenderAuthenticationEnabled $False -DisplayName $listname -Name $listname -PrimarySmtpAddress $listname -Alias $listname_nodomain
}

Import-Csv -Path $file_arg | ForEach-Object {
	
    Write-Host "Adding mail $($_.Account) to the Distribution List"
    try{
        Add-DistributionGroupMember -Identity $listname -Member $($_.Account)
    }catch{
        Write-Host "[$listname] Errors adding $($_.Account)" -ForegroundColor Red
    }
    
}