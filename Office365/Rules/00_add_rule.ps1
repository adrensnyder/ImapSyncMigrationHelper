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

# Module install
$modules = @(
    "MSAL.PS",
    "PsIni"
)

foreach ($module in $modules) {
    if (-not (Get-Module -Name $module -ListAvailable)) {
        # Install the module
        Write-Host "Install $module"
        Install-Module -Repository $REPO -Name $module -Scope CurrentUser -Force -AllowClobber
    } else {
        Write-Host "$module is already installed."
    }
}

Import-Module PsIni

# Load INI
$FileIni = $PSScriptRoot + "\" + "00_add_rule.ini"
$configData = Get-IniContent -FilePath $FileIni

$clientId = $configData.Config.clientId
$tenantId = $configData.Config.tenantId
$clientSecret = $configData.Config.clientSecret

# Set the endpoint URI di Microsoft Graph
$graphApiUri = "https://graph.microsoft.com/v1.0"

# Create folder function
function CreateFolder {

    param (
        [string]$VarMailbox,
        [string]$VarPercorso
    )

    $VarCartellaDestinazione = ""

    echo "TC:$TipoCreazione MB:$VarMailbox C:$VarPercorso"

    $url = ""
    $body = ""

    
    $PercorsoArray = $Percorso -split '\\'
    $Count = 0
    $CountPrev = 0

    $PercorsoIDPrev = ""

    $cartellacreata = $True

    foreach ($PercorsoSingolo in $PercorsoArray) {

        if ( $Count -eq 0 -and $cartellacreata -eq $True ) {
            $url = "$graphApiUri/users/$VarMailbox/mailFolders"

            $body = @{
                displayName = $PercorsoSingolo
            }

            $VarCartellaDestinazione = $PercorsoSingolo
        } else {
            $CountPrev = [INT]$Count - 1
        }

        if ( $Count -eq 1 -and $cartellacreata -eq $True  ) {

            $Folders = (Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/users/$VarMailbox/mailFolders" -Headers $headers).value
            $FolderID = ($Folders | Where-Object {$_.displayName -eq $PercorsoArray[$CountPrev]}).id
            $PercorsoIDPrev = $FolderID

            $url = "$graphApiUri/users/$VarMailbox/mailFolders/$FolderID/childFolders"

            $body = @{
               displayName = $PercorsoSingolo
            }

            $VarCartellaDestinazione = $VarCartellaDestinazione + "\" + $PercorsoSingolo          
        }

        if ( $Count -gt 1 -and $cartellacreata -eq $True  ) {

            $Folders = (Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/users/$VarMailbox/mailFolders/$PercorsoIDPrev/ChildFolders" -Headers $headers).value
            $FolderID = ($Folders | Where-Object {$_.displayName -eq $PercorsoArray[$CountPrev]}).id
            $PercorsoIDPrev = $FolderID

            $url = "$graphApiUri/users/$VarMailbox/mailFolders/$FolderID/childFolders"

            $body = @{
               displayName = $PercorsoSingolo
            }

            $VarCartellaDestinazione = $VarCartellaDestinazione + "\" + $PercorsoSingolo          

        }

        # Make the POST request to create the folder
        $messaggio = "Creating the folder: `"$VarCartellaDestinazione`""
    
        #write-host "[$Count] $url | $PercorsoIDPrev"
        #write-host ""

        Write-Host -NoNewLine ( $messaggio )

        try {

            $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body ($body | ConvertTo-Json) -ContentType "application/json; charset=utf-8"
            Write-Host "`r(Folder created) $messaggio"
        } catch {
            $errore = $_
            if ( $errore -like "*(409)*") {
                Write-Host "`r(Folder exists) $messaggio" 

            } else {
                Write-Host -ForegroundColor Red "`r(ERRORE: Folder not created) $messaggio"
                Write-Host -ForegroundColor Red $_
                $cartellacreata = $False
            }

        }

        $Count = [int]$Count + [int]1

    }

    return $cartellacreata
}

# Programmazione

$file_arg = $args[0]
Write-Host "Check that the file $file_arg has been saved in UTF-8 format"
Pause

if ( [string]::IsNullOrEmpty($file_arg) )  {
    Write-Host "Insert the file with the rules as a parameter" -ForegroundColor Red
    exit
}

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

# --- CREATING FOLDER

# Get an access token using the app credentials
$tokenResponse = Get-MsalToken -ClientId $clientId -ClientSecret (ConvertTo-SecureString $clientSecret -AsPlainText -Force) -TenantId $tenantId -Scope "https://graph.microsoft.com/.default" -AzureCloudInstance 1

# Check if the login was successful
if (-not $tokenResponse.AccessToken) {
    Write-Host "Connection to MSAL for the creation folder function failed"
    exit
}

$headers = @{
    Authorization = "Bearer $($tokenResponse.AccessToken)"
}

# --- CREAZIONE CARTELLE

Write-Host "- Managing Rule from $file_arg" -ForegroundColor Green

$numberOfRows = (Get-Content -Path $file_arg | Measure-Object -Line).Lines
$CountLines = 0

Import-Csv -Path $file_arg | ForEach-Object {
    
    $CountLines = [INT]$CountLines + 1

	Write-Host ""
    Write-Host -ForegroundColor Green "-- [$CountLines/$numberOfRows] Adding Rule |Account:$($_.Account) |Send:$($_.Sender) |Recip:$($_.Recipient) |Path:$($_.Path)"
    try{

        $mailbox = $($_.Account)
        $mittente = $($_.Mittente)
        $destinatario = $($_.Recipient)

        if ( $mittente -and $destinatario ) {
            Write-Host -ForegroundColor Red "Both Sender and Recipient cannot be filled in"
            continue
        }        

        $Percorso = $($_.Path)

        $CreaRegola = [System.Convert]::ToBoolean($($_.CreaRegola))

        $cartellaDestinazione_Completa = $mailbox + ":\" + $Percorso
        $MarkAsRead = [System.Convert]::ToBoolean($($_.Read))
        $StopProcessing = [System.Convert]::ToBoolean($($_.StopRules))

        $cartellacreata = CreateFolder -VarMailbox $mailbox -VarPercorso $Percorso

        if ( $cartellacreata -and $CreaRegola) {
                try {
                    
                    $ruleName = ""

                    if ($mittente) {
                        $ruleName = "Sender $mittente to $Percorso"
                    }

                    if ($destinatario) {
                        $ruleName = "Recipient $destinatario to $Percorso"
                    }

                    $ruleExist = Get-InboxRule -Mailbox $mailbox | Where-Object { $_.Name -eq $ruleName }

                    if ($ruleExist.count -eq 0) {

                        $newRule = ""

                        if ($mittente) {
                            $newRule = New-InboxRule -Name $ruleName -Mailbox $mailbox -MoveToFolder $cartellaDestinazione_Completa -FromAddressContainsWords $mittente -MarkAsRead $MarkAsRead -StopProcessingRules $StopProcessing
                        }

                        if ($destinatario) {
                            $newRule = New-InboxRule -Name $ruleName -Mailbox $mailbox -MoveToFolder $cartellaDestinazione_Completa -RecipientAddressContainsWords $destinatario -MarkAsRead $MarkAsRead -StopProcessingRules $StopProcessing
                        }

                        if ($newRule) {
                            Write-Host "Rule created"
                        } else {
                            write-host -ForegroundColor Red "> ERRORE: Rule not created"
                            Write-Host -ForegroundColor Red $_
                        }
                    } else {
                        Write-Host "The Rule exists"
                    }
                } catch {
                    write-host -ForegroundColor Red "> ERRORE: Rule not created" 
                    Write-Host -ForegroundColor Red $_
                }
            } 
        
    }catch{
        Write-Host "An error as occured" -ForegroundColor Red
        Write-Host -ForegroundColor Red $_
    }
    
}