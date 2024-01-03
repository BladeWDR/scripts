#This is a script I use in my MDT deployments as a part of a task sequence.
#function to set the power plan in Windows to high performance.

function powerPlanConfiguration {

    #first we need to grab the GUID of the high performance plan since it may vary across systems.
    $powerPlans = powercfg /list
    $highPerformancePlan = $powerPlans | Select-String "High Performance"

    if ($highPerformancePlan) {
    $guid = ($highPerformancePlan -split ' ')[3].Trim()
    Write-Host "GUID of High Performance Plan: $guid"
    Write-Host "Setting power plan to high performance."
    powercfg -setactive $guid
}   else {
    Write-Host "High Performance Plan not found on this computer."
}

# function createPowerPlan {
#
#     #define the name of our new scheme
#     $powerSchemeName = "MDT High Performance"
#
#     #Get the GUID of the active scheme.
#     $activeScheme = $(powercfg -getactivescheme).split()[3]
#
#     #output the names of all schemes.
#     $schemes = powercfg /list | Out-String -Stream
#
#     $mdtScheme = $schemes | Where-Object { $_ -match $powerSchemeName }
#
#     $PowerGUID = '4f971e89-eebd-4455-a8de-9e59040e7347'
#     $PowerButtonGUID = '7648efa3-dd9c-4e3e-b566-50f929386280'
#     $LidClosedGUID = '5ca83367-6e45-459f-a27b-476b1d01c936'
#     $SleepGUID = '238c9fa8-0aad-41ed-83f4-97be242c8f20'
#
#     if ($null -eq $mdtScheme){
#
#         Write-Host "Power scheme '$mdtScheme' not found. Adding..."
#
#         powercfg /duplicatescheme $activeScheme
#         powercfg -setactive ($powerSchemeName).split[3]
#         #Set the power button to shut down the machine when pressed.
#         powercfg /setdcvalueindex $powerSchemeName $PowerGUID $PowerButtonGUID 3
#         #Set the computer to never sleep automatically.
#         #Set the computer screen timeout.
#         # add a conditional here to set the lid close action if the device is a laptop. 
#
#     }
#     else {
#         Write-Host "Power scheme '$powerSchemeName' already exists."
#     }
#
# }

#calls the above function.
powerPlanConfiguration

#set the monitor timeout to a reasonable time and set the PC to never sleep.
powercfg -Change monitor-timeout-ac 30
powercfg -Change standby-timeout-ac 0





    }

