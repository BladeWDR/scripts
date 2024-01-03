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

#calls the above function.
powerPlanConfiguration

#set the monitor timeout to a reasonable time and set the PC to never sleep.
powercfg -Change monitor-timeout-ac 30
powercfg -Change standby-timeout-ac 0





    }
