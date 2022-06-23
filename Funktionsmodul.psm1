function Get-KeePassPW {
   
    param (
        [Parameter(Mandatory)][string]$AccountName,
        [Parameter(Mandatory)][string]$VaultName,
        [Parameter(Mandatory)][string]$VaultPath
    )

    <#
    .SYNOPSIS
    Function to get the Password from a certain User out of a .kdbx file.

    .DESCRIPTION
    The function creates a new Windows SecretVault, with integrated KeePass Modules.
    The Vault is registered and the Username and Password that are given as parameters in the function
    are printed out. The Password is in PlainText, since we also give the KeyFile in the parameters to connect
    to the .kdbx Database, which is also a Parameter thats given. All Parameters are Mandatory.

    .PARAMETER AccountName
    Is the User from the .kdbx File that you want to get the Password from.
    .PARAMETER VaultName
    Is the Name of the Vault that is registered. Its also the Name of the .kdbx and .keyx File
    (the .kdbx and the .keyx File must be the same name!)
    .PARAMETER VaultPath
    Is the Path of the .kdbx and .keyx Files (must be stored at the same place!)

    .EXAMPLE
    Get-KeePassPW -AccountName "Test" -Vaultname "Vault1" -VaultPath "C:\myDatabase"
    #>

    #If the Path doesn't end with '\'
    if ($VaultPath -notmatch '\$') {
        $VaultPath += '\'
    }

    #Initializing Paths
    $KeePassPath = $VaultPath + $VaultName + ".kdbx"
    $Keypath = $VaultPath + $VaultName + ".keyx"
    if (!(Test-Path $KeePassPath)) {
        Write-Host "The File $KeePassPath was not found!"
        Exit 1
    }

    if (!(Test-Path $Keypath)) {
        Write-Host "The File $Keypath was not found!"
        Exit 1
    }
    #Setting Parameter
    $VaultParams = @{ Path = $KeePassPath
        UseMasterPassword  = $false
        KeyPath            = $Keypath
    }

    try {
        Register-SecretVault -Name $VaultName -ModuleName SecretManagement.keepass -VaultParameters $VaultParams
    }

    catch {
        "Fehler beim Registrieren des Vaults."
        Unregister-SecretVault -Name $VaultName
        Exit 1 
    }

    try {
        #Gets Secrets
        $Securestring = Get-Secret -Name $AccountName -Vault $VaultName -ErrorAction Stop
    }

    catch {
        "Fehler beim Abrufen der Benutzerdaten."
        Exit 1
    }

    #Converts Secure String to PlainText
    $Password = ConvertFrom-SecureString -SecureString $Securestring.Password -AsPlainText

    #Unregistering Vault
    Unregister-SecretVault -Name $VaultName 

    #Create Array
    $Identity = new-object psobject
    $Identity  | add-member noteproperty Username $Securestring.UserName
    $Identity  | add-member noteproperty Password $Password
    return $Identity
}

## Install Modules if needed
Function Install-ModuleIfNeeded {
    param (
        [Parameter(Mandatory)][string]$Module
    )
    <#
    .SYNOPSIS
    Checks if a Module is already installed.
    .DESCRIPTION
    Takes a Module Name as a Parameter and checks if its already installed.
    If not, the Module gets installed.
    .PARAMETER Module
    Is the Module thats given to check if its installed or not.

    .EXAMPLE
    Install-ModuleIfNeeded "chocolatey"
    #>

    #check if module installed
    if ( Get-Module -ListAvailable -Name $Module) {
        Write-Debug "Module $Module is installed"
    }

    else {
        #If not installed, the Corsinvest Module will be installed
        try { Install-Module -Name $Module -force }
        catch {
            Write-Debug "Error: Module failed to install!"
            exit 1
        }
    }    
}

## Returning Time Window Function
Function Get-TimeWindow {
    param (
        [Parameter(Mandatory)][datetime]$Date
    )

    <#
    .SYNOPSIS
    Shows in which Time Window the given Date is.
   
    .DESCRIPTION
    The function takes a "Date" as a Parameter and defines, whether the
    given date is in Time Window 1, 2, 3 or 4.

    .PARAMETER Date
    Is the Date that you want to check the Time Window of.

    .EXAMPLE
    Get-TimeWindow($Get-Date)
    #>

    # Time Windows (in minutes of time)
    $TIMEWINDOW1_START = 0
    $TIMEWINDOW1_END = 359
    $TIMEWINDOW2_START = 360
    $TIMEWINDOW2_END = 719
    $TIMEWINDOW3_START = 720
    $TIMEWINDOW3_END = 1079
    $TIMEWINDOW4_START = 1080
    $TIMEWINDOW4_END = 1440

    if ([int](($Date).TimeOfDay.TotalMinutes) -in $TIMEWINDOW1_START..$TIMEWINDOW1_END) {
        Write-Debug "Timewindow 1 selected"
        $Timewindow = 1
    }

    if ([int](($Date).TimeOfDay.TotalMinutes) -in $TIMEWINDOW2_START..$TIMEWINDOW2_END) {
        Write-Debug "Timewindow 2 selected"
        $Timewindow = 2
    }

    if ([int](($Date).TimeOfDay.TotalMinutes) -in $TIMEWINDOW3_START..$TIMEWINDOW3_END) {
        Write-Debug "Timewindow 3 selected"
        $Timewindow = 3
    }

    if ([int](($Date).TimeOfDay.TotalMinutes) -in $TIMEWINDOW4_START..$TIMEWINDOW4_END) {
        Write-Debug "Timewindow 4 selected"
        $Timewindow = 4
    }

    #Returns the current Timewindow
    Write-Debug "Returning $Timewindow"
    return $Timewindow
}

Function Send-AlarmTextMessage {
    param (
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][System.Boolean]$alarm,
        [Parameter(Mandatory)][string]$poshgramBotToken,
        [Parameter(Mandatory)][string]$poshgramBotId
    )

    <#
    .SYNOPSIS
    Checks if a Alert Message is needed to be sent.

    .DESCRIPTION
    Takes a Message, a Boolean (Alarm) and the credentials needed for the Poshgrambot as Parameters.
    The Message can be customized and the alarm needs to be either true or false. The Message gets sent to the Poshgrambot.

    .PARAMETER Message
    A short message which is sent to the Poshgrambot.

    .PARAMETER alarm
    If true, the message will be sent to the Poshgrambot. If false, no message will be sent.

    .PARAMETER poshgramBotToken
    Is the token for the PoshgramBot

    .PARAMETER poshgramBotId
    Is the ID of the PoshgramBot

    .EXAMPLE
    An example
    Send-AlarmTextMessage -Message $Message -alarm $true -poshgramBotToken "12345678" poshgramBotId "9876543"
    #>

    $Messagelenght = $Message | Measure-Object -Character | Select-Object -ExpandProperty Characters

    if (!($alarm) -and ($Messagelenght -ne 0)) {
        Write-Debug "No need to Send Telegrammmessage"
        Write-Debug "$Message"
    }
    else {
        try {
            Write-Debug "$Message"
            Send-TelegramTextMessage -BotToken $poshgramBotToken -ChatID $poshgramBotId -Message $Message
        }

        catch {
            Write-Debug "Error: The Message could not been sent!"
        }
    }
}