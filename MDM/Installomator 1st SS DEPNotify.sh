#!/bin/sh

# Installomator 1st installation with DEPNotify window (for self Service deployment)
instance="" # Name of used instance

LOGO="" # "appstore", "jamf", "mosyleb", "mosylem", "addigy", "microsoft", "ws1", "kandji"

items=(dialog dockutil microsoftautoupdate supportapp applenyfonts applesfpro applesfmono applesfcompact xink zohoworkdrivetruesync textmate 1password7 wwdc theunarchiver keka microsoftedge microsoftteams microsoftonedrive microsoftoffice365)
# Remember: dialog dockutil

installomatorOptions="NOTIFY=all BLOCKING_PROCESS_ACTION=prompt_user"

# DEPNotify display settings, change as desired
title="Installing Apps and other software"
message="Please wait while we download and install the needed software."
endMessage="Installation complete! Please reboot to activate FileVault."
errorMessage="A problem was encountered setting up this Mac. Please contact IT."

######################################################################
# Installomator 1st DEPNotify
#
# Installation using Installomator showing progress with DEPNotify
# Great stand-alone solution if installs are only done using Installomator.
# No customization below…
######################################################################
# This script can be used to install software using Installomator.
# Script will start DEPNotify to display a progress bar.
# Progress bar moves between installations
######################################################################
# Other installomatorOptions:
#   LOGGING=REQ
#   LOGGING=DEBUG
#   LOGGING=WARN
#   BLOCKING_PROCESS_ACTION=ignore
#   BLOCKING_PROCESS_ACTION=tell_user
#   BLOCKING_PROCESS_ACTION=tell_user_then_quit
#   BLOCKING_PROCESS_ACTION=prompt_user
#   BLOCKING_PROCESS_ACTION=prompt_user_loop
#   BLOCKING_PROCESS_ACTION=prompt_user_then_kill
#   BLOCKING_PROCESS_ACTION=quit
#   BLOCKING_PROCESS_ACTION=kill
#   NOTIFY=all
#   NOTIFY=success
#   NOTIFY=silent
#   IGNORE_APP_STORE_APPS=yes
#   INSTALL=force
######################################################################
#
#  This script made by Søren Theilgaard
#  https://github.com/Theile
#  Twitter and MacAdmins Slack: @theilgaard
#
#  Some functions and code from Installomator:
#  https://github.com/Installomator/Installomator
#
######################################################################
scriptVersion="9.7"
# v.  9.7   : 2022-12-19 : Only kill the caffeinate process we create
# v.  9.6   : 2022-11-15 : GitHub API call is first, only try alternative if that fails.
# v.  9.5   : 2022-09-21 : change of GitHub download
# v.  9.4   : 2022-09-14 : downloadURL can fall back on GitHub API
# v.  9.3   : 2022-08-29 : installomatorOptions in quotes and ignore blocking processes. Improved installation with looping if it fails, so it can try again. Improved GitHub handling. ws1 support.
# v.  9.2.2 : 2022-06-17 : installomatorOptions introduced. Check 1.1.1.1 for internet connection.
# v.  9.2.1 : 2022-05-30 : Some changes to logging
# v.  9.2   : 2022-05-19 : Built in installer for Installlomator, and display dialog if error happens. Now universal script for all supported MDMs based on LOGO variable.
# v.  9.1   : 2022-04-13 : Using INSTALL=force in Label only, so Microsoft labels will not start updating
# v.  9.0.1 : 2022-02-21 : LOGO=addigy, few more "true" lines, and errorOutput on error
# v.  9.0.0 : 2022-02-14 : Updated for Inst. 9.0, Logging improved with printlog
######################################################################

export PATH=/usr/bin:/bin:/usr/sbin:/sbin

# Check before running
case $LOGO in
    addigy|microsoft)
        conditionFile="/var/db/.Installomator1stDone"
        # Addigy and Microsoft Endpoint Manager (Intune) need a check for a touched file
        if [ -e "$conditionFile" ]; then
            echo "$LOGO setup detected"
            echo "$conditionFile exists, so we exit."
            exit 0
        else
            echo "$conditionFile not found, so we continue…"
        fi
        ;;
esac

# Mark: Constants, logging and caffeinate
log_message="$instance: Installomator 1st with DEPNotify, v$scriptVersion"
label="1st-v$scriptVersion"

log_location="/private/var/log/Installomator.log"
printlog(){
    timestamp=$(date +%F\ %T)
    if [[ "$(whoami)" == "root" ]]; then
        echo "$timestamp :: $label : $1" | tee -a $log_location
    else
        echo "$timestamp :: $label : $1"
    fi
}
printlog "[LOG-BEGIN] ${log_message}"

# Internet check
if [[ "$(nc -z -v -G 10 1.1.1.1 53 2>&1 | grep -io "succeeded")" != "succeeded" ]]; then
    printlog "ERROR. No internet connection, we cannot continue."
    exit 90
fi

# No sleeping
/usr/bin/caffeinate -d -i -m -u &
caffeinatepid=$!
caffexit () {
    kill "$caffeinatepid" || true
    printlog "[LOG-END] Status $1"
    exit $1
}

# Command-file to DEPNotify
DEPNOTIFY_LOG="/var/tmp/depnotify.log"

# Counters
errorCount=0
countLabels=${#items[@]}
printlog "Total installations: $countLabels"

# Using LOGO variable to specify MDM and shown logo
case $LOGO in
    appstore)
        # Apple App Store on Mac
        if [[ $(sw_vers -buildVersion) > "19" ]]; then
            LOGO_PATH="/System/Applications/App Store.app/Contents/Resources/AppIcon.icns"
        else
            LOGO_PATH="/Applications/App Store.app/Contents/Resources/AppIcon.icns"
        fi
        ;;
    jamf)
        # Jamf Pro
        LOGO_PATH="/Library/Application Support/JAMF/Jamf.app/Contents/Resources/AppIcon.icns"
        ;;
    mosyleb)
        # Mosyle Business
        LOGO_PATH="/Applications/Self-Service.app/Contents/Resources/AppIcon.icns"
        ;;
    mosylem)
        # Mosyle Manager (education)
        LOGO_PATH="/Applications/Manager.app/Contents/Resources/AppIcon.icns"
        ;;
    addigy)
        # Addigy
        LOGO_PATH="/Library/Addigy/macmanage/MacManage.app/Contents/Resources/atom.icns"
        ;;
    microsoft)
        # Microsoft Endpoint Manager (Intune)
        LOGO_PATH="/Library/Intune/Microsoft Intune Agent.app/Contents/Resources/AppIcon.icns"
        ;;
    ws1)
        # Workspace ONE (AirWatch)
        LOGO_PATH="/Applications/Workspace ONE Intelligent Hub.app/Contents/Resources/AppIcon.icns"
        ;;
    kandji)
        # Kandji
        LOGO="/Applications/Kandji Self Service.app/Contents/Resources/AppIcon.icns"
        ;;
esac
if [[ ! -a "${LOGO_PATH}" ]]; then
    printlog "ERROR in LOGO_PATH '${LOGO_PATH}', setting Mac App Store."
    if [[ $(/usr/bin/sw_vers -buildVersion) > "19" ]]; then
        LOGO_PATH="/System/Applications/App Store.app/Contents/Resources/AppIcon.icns"
    else
        LOGO_PATH="/Applications/App Store.app/Contents/Resources/AppIcon.icns"
    fi
fi
printlog "LOGO: $LOGO - LOGO_PATH: $LOGO_PATH"

# Mark: Functions
printlog "depnotify_command function"
echo "" > $DEPNOTIFY_LOG || true
function depnotify_command(){
    printlog "DEPNotify-command: $1"
    echo "$1" >> $DEPNOTIFY_LOG || true
}

printlog "startDEPNotify function"
function startDEPNotify() {
    currentUser="$(stat -f "%Su" /dev/console)"
    currentUserID=$(id -u "$currentUser")
    launchctl asuser $currentUserID open -a "/Applications/Utilities/DEPNotify.app/Contents/MacOS/DEPNotify" --args -path "$DEPNOTIFY_LOG" || true # --args -fullScreen
    sleep 5
    depnotify_command "Command: KillCommandFile:"
    depnotify_command "Command: MainTitle: $title"
    depnotify_command "Command: Image: $LOGO_PATH"
    depnotify_command "Command: MainText: $message"
    depnotify_command "Command: Determinate: $countLabels"
}

# Notify the user using AppleScript
printlog "displayDialog function"
function displayDialog(){
    currentUser="$(stat -f "%Su" /dev/console)"
    currentUserID=$(id -u "$currentUser")
    if [[ "$currentUser" != "" ]]; then
        launchctl asuser $currentUserID sudo -u $currentUser osascript -e "button returned of (display dialog \"$message\" buttons {\"OK\"} default button \"OK\" with icon POSIX file \"$LOGO_PATH\")" || true
    fi
}

# Mark: Code
name="Installomator"
printlog "$name check for installation"
# download URL, version and Expected Team ID
# Method for GitHub pkg
gitusername="Installomator"
gitreponame="Installomator"
#printlog "$gitusername $gitreponame"
filetype="pkg"
downloadURL=$(curl -sfL "https://api.github.com/repos/$gitusername/$gitreponame/releases/latest" | awk -F '"' "/browser_download_url/ && /$filetype\"/ { print \$4; exit }")
if [[ "$(echo $downloadURL | grep -ioE "https.*.$filetype")" == "" ]]; then
    printlog "GitHub API failed, trying failover."
    #downloadURL="https://github.com$(curl -sfL "https://github.com/$gitusername/$gitreponame/releases/latest" | tr '"' "\n" | grep -i "^/.*\/releases\/download\/.*\.$filetype" | head -1)"
    downloadURL="https://github.com$(curl -sfL "$(curl -sfL "https://github.com/$gitusername/$gitreponame/releases/latest" | tr '"' "\n" | grep -i "expanded_assets" | head -1)" | tr '"' "\n" | grep -i "^/.*\/releases\/download\/.*\.$filetype" | head -1)"
fi
#printlog "$downloadURL"
appNewVersion=$(curl -sLI "https://github.com/$gitusername/$gitreponame/releases/latest" | grep -i "^location" | tr "/" "\n" | tail -1 | sed 's/[^0-9\.]//g')
#printlog "$appNewVersion"
expectedTeamID="JME5BW3F3R"

destFile="/usr/local/Installomator/Installomator.sh"
currentInstalledVersion="$(${destFile} version 2>/dev/null || true)"
printlog "${destFile} version: $currentInstalledVersion"
if [[ ! -e "${destFile}" || "$currentInstalledVersion" != "$appNewVersion" ]]; then
    printlog "$name not found or version not latest."
    printlog "${destFile}"
    printlog "Installing version ${appNewVersion} ..."
    # Create temporary working directory
    tmpDir="$(mktemp -d || true)"
    printlog "Created working directory '$tmpDir'"
    # Download the installer package
    printlog "Downloading $name package version $appNewVersion from: $downloadURL"
    installationCount=0
    exitCode=9
    while [[ $installationCount -lt 3 && $exitCode -gt 0 ]]; do
        curlDownload=$(curl -Ls "$downloadURL" -o "$tmpDir/$name.pkg" || true)
        curlDownloadStatus=$(echo $?)
        if [[ $curlDownloadStatus -ne 0 ]]; then
            printlog "error downloading $downloadURL, with status $curlDownloadStatus"
            printlog "${curlDownload}"
            exitCode=1
        else
            printlog "Download $name succes."
            # Verify the download
            teamID=$(spctl -a -vv -t install "$tmpDir/$name.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()' || true)
            printlog "Team ID for downloaded package: $teamID"
            # Install the package if Team ID validates
            if [ "$expectedTeamID" = "$teamID" ] || [ "$expectedTeamID" = "" ]; then
                printlog "$name package verified. Installing package '$tmpDir/$name.pkg'."
                pkgInstall=$(installer -verbose -dumplog -pkg "$tmpDir/$name.pkg" -target "/" 2>&1)
                pkgInstallStatus=$(echo $?)
                if [[ $pkgInstallStatus -ne 0 ]]; then
                    printlog "ERROR. $name package installation failed."
                    printlog "${pkgInstall}"
                    exitCode=2
                else
                    printlog "Installing $name package succes."
                    exitCode=0
                fi
            else
                printlog "ERROR. Package verification failed for $name before package installation could start. Download link may be invalid."
                exitCode=3
            fi
        fi
        ((installationCount++))
        printlog "$installationCount time(s), exitCode $exitCode"
        if [[ $installationCount -lt 3 ]]; then
            if [[ $exitCode -gt 0 ]]; then
                printlog "Sleep a bit before trying download and install again. $installationCount time(s)."
                printlog "Remove $(rm -fv "$tmpDir/$name.pkg" || true)"
                sleep 2
            fi
        else
            printlog "Download and install of $name succes."
        fi
    done
    # Remove the temporary working directory
    printlog "Deleting working directory '$tmpDir' and its contents."
    printlog "Remove $(rm -Rfv "${tmpDir}" || true)"
    # Handle installation errors
    if [[ $exitCode != 0 ]]; then
        printlog "ERROR. Installation of $name failed. Aborting."
        caffexit $exitCode
    else
        printlog "$name version $appNewVersion installed!"
    fi
else
    printlog "$name version $appNewVersion already found. Perfect!"
fi

# Installing DEPNotify
cmdOutput="$( ${destFile} depnotify LOGO=$LOGO NOTIFY=silent BLOCKING_PROCESS_ACTION=ignore LOGGING=WARN || true )"
exitStatus="$( echo "${cmdOutput}" | grep --binary-files=text -i "exit" | tail -1 | sed -E 's/.*exit code ([0-9]).*/\1/g' || true )"
printlog "DEPNotify install result: $exitStatus"

itemName=""
errorLabels=""
((countLabels++))
((countLabels--))
printlog "$countLabels labels to install"

startDEPNotify

for item in "${items[@]}"; do
    # Check if DEPNotify is running and try open it if not
    if ! pgrep -xq "DEPNotify"; then
        startDEPNotify
    fi
    itemName=$( ${destFile} ${item} RETURN_LABEL_NAME=1 LOGGING=REQ INSTALL=force | tail -1 || true )
    if [[ "$itemName" != "#" ]]; then
        depnotify_command "Status: $itemName installing…"
    else
        depnotify_command "Status: $item installing…"
    fi
    printlog "$item $itemName"
    cmdOutput="$( ${destFile} ${item} LOGO=$LOGO ${installomatorOptions} || true )"
    #cmdOutput="2022-05-19 13:20:45 : REQ   : installomator : ################## End Installomator, exit code 0"
    exitStatus="$( echo "${cmdOutput}" | grep --binary-files=text -i "exit" | tail -1 | sed -E 's/.*exit code ([0-9]).*/\1/g' || true )"
    if [[ ${exitStatus} -eq 0 ]] ; then
        printlog "${item} succesfully installed."
        warnOutput="$( echo "${cmdOutput}" | grep --binary-files=text "WARN" || true )"
        printlog "$warnOutput"
    else
        printlog "Error installing ${item}. Exit code ${exitStatus}"
        #printlog "$cmdOutput"
        errorOutput="$( echo "${cmdOutput}" | grep --binary-files=text -i "error" || true )"
        printlog "$errorOutput"
        ((errorCount++))
        errorLabels="$errorLabels ${item}"
    fi
    ((countLabels--))
    itemName=""
done

# Mark: Finishing
# Prevent re-run of script if conditionFile is set
if [[ ! -z "$conditionFile" ]]; then
    printlog "Touching condition file so script will not run again"
    touch "$conditionFile" || true
    printlog "$(ls -al "$conditionFile" || true)"
fi

# Show error to user if any
printlog "Errors: $errorCount"
if [[ $errorCount -ne 0 ]]; then
    errorMessage="${errorMessage} Total errors: $errorCount"
    message="$errorMessage"
    displayDialog &
    endMessage="$message"
    printlog "errorLabels: $errorLabels"
fi

depnotify_command "Command: MainText: $endMessage"
depnotify_command "Command: Quit: $endMessage"

sleep 1
printlog "Remove $(rm -fv $DEPNOTIFY_LOG || true)"

printlog "Ending"
caffexit $errorCount
