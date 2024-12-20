#!/bin/bash
# nextcloud-update.sh	Script to update Nextcloud to a specific version
# github: https://github.com/unclesam87/nextcloud-update
# thx to: devgitw23 for bugfixing and log function
# thx to: carsten rieger for the inspiration and his great tutorials
clear
# Add error trapping
trap 'if [[ $? != 1 ]] && [[ $? != 2 ]]; then echo "Error on line $LINENO"; fi' ERR

# running as root
if [[ "$(id -u)" != "0" ]]; then
	echo ""
	echo "Please run as root!"
	echo ""
	exit 1
fi

# Initialize variables with default values
version=""
folder=""
remove_bkpfolder=false

# Function to display usage
usage() {
    echo ""
    echo "Usage: $0 -v <version> -f <folder>"
    echo "  -v    Specify the version (e.g. 1.2.3)"
    echo "  -f    Specify the folder path (e.g. /var/www/cloudfolder)"
    echo "  -r    If argumented, then remove the bkp_folder at the end of the script"
    echo ""
    exit 1
}

# Function to compare versions
compare_versions() {
    local local_ver1="$1"  # installed version
    local local_ver2="$2"  # target version

    # Split the version strings into arrays
    IFS='.' read -r -a v1 <<< "$local_ver1"
    IFS='.' read -r -a v2 <<< "$local_ver2"

    # Pad the shorter version with zeros
    while [[ ${#v1[@]} -lt ${#v2[@]} ]]; do
        v1+=("0")
    done
    while [[ ${#v2[@]} -lt ${#v1[@]} ]]; do
        v2+=("0")
    done

    # Compare each segment
    for i in "${!v1[@]}"; do
        if ((10#${v1[i]} > 10#${v2[i]})); then
            return 1  # Error: installed version newer
        elif ((10#${v1[i]} < 10#${v2[i]})); then
            return 0  # Success: can update
        fi
    done

    # If all segments are equal
    return 1  # Error: same version
}

# Parse command-line arguments
while getopts ":v:f:r" opt; do
    case $opt in
        v)
            version="$OPTARG"
            ;;
        f)
            folder="$OPTARG"
            ;;
        r)
            remove_bkpfolder=true
            ;;
        \?)
            echo ""
            echo "Invalid option: -$OPTARG"
            echo ""
            usage
            ;;
        :)
            echo ""
            echo "Option -$OPTARG requires an argument."
            echo ""
            usage
            ;;
    esac
done

# Shift the processed options away
shift $((OPTIND -1))
# Normalize the folder variable to extract only the folder name
folder_name=$(basename "$folder")
# other variables
folder_bkp="${folder}_bkp" 
# Ensure the log directory exists
log_dir="/var/log/nextcloud"
if [[ ! -d "$log_dir" ]]; then
    mkdir -p "$log_dir"
fi

# Redirect output to log file
exec > >(tee -i -a "$log_dir/$folder_name-update.log")
exec 2>&1

echo "Starting script..."

# Check if folder ends with /
if [[ "$folder" == */ ]]; then
    echo ""
    echo "The folder path must not end with a '/'. Please remove the trailing slash."
    echo ""
    exit 1
fi

# Check if version and folder are set
if [[ -z "$version" ]] || [[ -z "$folder" ]]; then
    echo ""
    echo "Both version and folder must be specified."
    echo ""
    usage
fi

echo "Version: $version"
echo "Folder: $folder"

# Extract the versionstring from occ status
config_version=$(sudo -u www-data php "$folder/occ" status | grep -oP '(?<=versionstring: )\d+\.\d+\.\d+(?:\.\d+)?')

echo "Config version: $config_version"

# Check if the config_version variable is not empty
if [[ -z "$config_version" ]]; then
    echo ""
    echo "Could not find a valid version in occ status."
    echo ""
    exit 1
fi

# Modify the version comparison section
echo "Comparing versions: $config_version vs $version"
compare_versions "$config_version" "$version"
compare_result=$?

if [[ $compare_result -eq 0 ]]; then
    echo "The given version is newer than the installed version in the config. Proceeding with the update."
    echo ""
    cd /tmp
    if test -f "nextcloud-$version.zip"; then
        echo "Removing existing nextcloud-$version.zip"
        rm nextcloud-$version.zip
    fi
    if [[ -d "nextcloud-$version" ]]; then
        echo "Removing existing nextcloud-$version directory"
        rm -rf nextcloud-$version
    fi
    echo ""
    echo "start installation at $(date '+%d-%m-%Y %H:%M:%S')"
    echo ""
    echo "nextcloud folder: $folder"
    echo "new nextcloud version should be $version"
    echo ""
    echo "download nextcloud version $version"
    echo ""
    wget -nv https://download.nextcloud.com/server/releases/nextcloud-$version.zip
    echo ""
    echo "done"
    echo ""
    echo "unzip nextcloud zip"
    unzip -q nextcloud-$version 
    echo ""
    echo "nextcloud update to version $version"
    echo ""
    echo "stop cron"
    echo ""
    systemctl stop cron
    # turn on maintenance mode for folder update
    sudo -u www-data php $folder/occ maintenance:mode --on
    echo ""
    echo "create backup folder and update folder with new version"
    echo ""
    mv $folder "$folder_bkp"
    mv nextcloud $folder
    cp "$folder_bkp"/config/config.php $folder/config/config.php
    echo "correct filetype owner and rights"
    echo ""
    chown -R www-data:www-data $folder
    find $folder/ -type d -exec chmod 750 {} \;
    find $folder/ -type f -exec chmod 640 {} \;
    sudo -u www-data php $folder/occ maintenance:mode --off
    echo ""
    echo "upgrade nextcloud"
    echo ""
    sudo -u www-data php $folder/occ upgrade -vv
    sudo -u www-data php $folder/occ db:add-missing-columns
    sudo -u www-data php $folder/occ db:add-missing-indices
    sudo -u www-data php $folder/occ db:add-missing-primary-keys
    sudo -u www-data php $folder/occ app:update --all
    sudo -u www-data php $folder/occ maintenance:theme:update
    # not longer needed
    sudo -u www-data php $folder/occ maintenance:repair --include-expensive
    echo ""
    echo "start cron"
    systemctl start cron
    rm nextcloud-$version.zip
    # If the remove flag is set, run the removal command
    if [[ "$remove_bkpfolder" = true ]]; then
        echo ""
        echo "Removing folder: $folder_bkp"
        echo ""
        rm -rf "$folder_bkp"
        if [[ $? -eq 0 ]]; then
            echo "Folder removed successfully."
        else
            echo "Failed to remove folder."
        fi
    fi
    echo ""
    echo "Update done at $(date '+%d-%m-%Y %H:%M:%S')"
    echo ""
    else
    echo ""
    echo "Cannot proceed: installed version ($config_version) is same or newer than target version ($version)"
    echo ""
    exit 1
fi

echo "Script completed."
exit 0