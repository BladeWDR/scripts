#This is a script I use in my MDT deployments as a part of a task sequence.
#function to set the power plan in Windows to high performance.

#checks to see if the device is a laptop and returns true if so.
function Detect-Laptop
{
    Param( [string]$computer = 'localhost' )
        $isLaptop = $false
#The chassis is the physical container that houses the components of a computer. Check if the machine’s chasis type is 9.Laptop 10.Notebook 14.Sub-Notebook
        if(Get-WmiObject -Class win32_systemenclosure -ComputerName $computer | Where-Object { $_.chassistypes -eq 9 -or $_.chassistypes -eq 10 -or $_.chassistypes -eq 14})
        { 
            $isLaptop = $true 
        }


    return $isLaptop
}


function Create-PowerPlan {

    #define the name of our new scheme
    $powerSchemeName = "MDT High Performance"

    #Get the GUID of the active scheme.
    $activeScheme = $(powercfg -getactivescheme).split()[3]

    #output the names of all schemes.
    $schemes = powercfg /list | Out-String -Stream

    $mdtScheme = $schemes | Where-Object { $_ -match $powerSchemeName }

    $PowerGUID = '4f971e89-eebd-4455-a8de-9e59040e7347'
    $PowerButtonGUID = '7648efa3-dd9c-4e3e-b566-50f929386280'
    $LidClosedGUID = '5ca83367-6e45-459f-a27b-476b1d01c936'
    $SleepGUID = '238c9fa8-0aad-41ed-83f4-97be242c8f20'
    $PCIGUID = '501a4d13-42af-4429-9fd1-a8218c268e20'
    $LinkStateGUID = 'ee12f906-d277-404b-b6da-e5fa1a576df5'

    if ($mdtScheme -eq $null){

        Write-Output "Power scheme '$powerSchemeName' not found. Adding...`n"
        $duplicate = cmd /c "powercfg /duplicatescheme $activeScheme"
        powercfg -setactive $duplicate.split()[3]
    	powercfg -changename ($duplicate).split()[3] $powerSchemeName
        $MDTPlanGUID = $(powercfg -getactivescheme).split()[3]

        #Set the power button to shut down the machine when pressed.
        powercfg /setdcvalueindex $MDTPlanGUID $PowerGUID $PowerButtonGUID 3
        powercfg /setacvalueindex $MDTPlanGUID $PowerGUID $PowerButtonGUID 3
        # add a conditional here to set the lid close action if the device is a laptop. 
        if ( Detect-Laptop ){
            powercfg /setdcvalueindex $MDTPlanGUID $PowerGUID $LidClosedGUID 15
            powercfg /setacvalueindex $MDTPlanGUID $PowerGUID $LidClosedGUID 0
        }
        #Set the Link State power management to none.
        powercfg /setacvalueindex $MDTPlanGUID $PCIGUID $LinkStateGUID 0
        #Set the computer to never sleep automatically while on AC power.
        powercfg -change -standby-timeout-ac 0
        #Set the computer screen timeout.
        powercfg -change -monitor-timeout-ac 30

    }
    else {
        Write-Output "Power scheme '$powerSchemeName' already exists."
    }

}

#calls the above function.

try {
    Create-PowerPlan
}
catch{
        Write-Warning $psitem.Exception.Message
    }

