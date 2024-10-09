#!/bin/bash
# running as root
clear
set -e
if [[ "$(id -u)" != "0" ]]; then
	echo
	echo "Please run as root!"
	echo 
	exit 1
fi
# Function to display help
usage() {
    echo "Usage: $0 -v <version> -f <folder>"
    echo "  -v    Specify the version (e.g. 1.2.3)"
    echo "  -f    Specify the folder path (e.g. /var/www/cloudfolder)"
    echo "  -r    Remove the bkp_folder at the end of the script""
    echo "   \? 	  print this usage"
    exit 1
}
remove_bkpfolder=false
# Parse command-line arguments
while getopts ":v:f:" opt; do
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
            echo "Invalid option: -$OPTARG" >&2
            usage
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            usage
            ;;
    esac
done

# Definition
chmod=$(command -v chmod)
chown=$(command -v chown)
clear=$(command -v clear)
cp=$(command -v cp)
date=$(command -v date)
echo=$(command -v echo)
mv=$(command -v mv)
find=$(command -v find)
rm=$(command -v rm)
grep=$(command -v grep)
sudo=$(command -v sudo)
systemctl=$(command -v systemctl)
wget=$(command -v wget)
unzip=$(command -v unzip)
# Variables
dt=$(${date} '+%d-%m-%Y')
folder_bkp="$folder"_bkp_"$dt"
# Logfile
exec > >(tee -i -a "/var/log/nextcloud/$folder-nextcloudupdate.log")
exec 2>&1
# Check if folder ends with /
if [[ "$folder" == */ ]]; then
    echo "The folder path must not end with a '/'. Please remove the trailing slash." >&2
    exit 1
fi
# Check if version and folder are set
if [[ -z "$version" ]] || [[ -z "$folder" ]]; then
    echo "Both version and folder must be specified." >&2
    usage
fi

# Extract the version from config.php
config_version=$(grep -oP "'version' => \'d+\.\d+\.\d+(?:\.\d+)?'" "$folder/config/config.php" | head -n 1)

# Function to compare versions
compare_versions() {
    local local_ver1="$1"
    local local_ver2="$2"

    # Split the version strings into arrays
    IFS='.' read -r -a v1 <<< "$local_ver1"
    IFS='.' read -r -a v2 <<< "$local_ver2"

    # Compare each segment
    for i in "${!v1[@]}"; do
        # If v2 doesn't have this segment, it's newer
        if [[ -z ${v2[i]} ]]; then
            return 1
        fi
        if (( 10#${v1[i]} < 10#${v2[i]} )); then
            return 1
        elif (( 10#${v1[i]} > 10#${v2[i]} )); then
            return 0
        fi
    done

    # If we finished checking, v1 is equal to or older than v2
    return 1
}

# Check if the config_version variable is not empty
if [[ -z "$config_version" ]]; then
    echo "Could not find a valid version in config.php."
    exit 1
fi

# Compare versions
if compare_versions "$config_version" "$version"; then
    echo "The version in the config is newer or the same as the specified version."
    exit 1
else
	echo "The specified version is newer than the version in the config."
	cd /tmp
	if test -f "nextcloud-$version.zip"
	then
	${rm} nextcloud-$version.zip
	fi
	if [ -d "nextcloud-$version" ]; then
	${rm} -rf nextcloud-$version
	fi
	${echo} ""
	${echo} "start installation at $(date '+%d-%m-%Y %H:%M:%S')"
	${echo} ""
	${echo} "nextcloud folder: $folder"
	${echo} "new nextcloud version should be $version"
	${echo} ""
	${echo} "download nextcloud version $version"
	${echo} ""
	${wget} -nv https://download.nextcloud.com/server/releases/nextcloud-$version.zip
	${echo} ""
	${echo} "done"
	${echo} ""
	${echo} "unzip nextcloud zip"
	${unzip} -q nextcloud-$version 
	${echo} ""
	${echo} "nextcloud update to version $version"
	${echo} ""
	${echo} "stop cron"
	${echo} ""
	${systemctl} stop cron
	# turn on maintenance mode for folder update
	${sudo} -u www-data php $folder/occ maintenance:mode --on
	${echo} ""
	${echo} "creat backup folder and update folder with new version"
	${echo} ""
	${mv} $folder "$folder_bkp"
	${mv} nextcloud $folder
	${cp} "$folder_bkp"/config/config.php $folder/config/config.php
	${echo} "correct filetype owner and rights"
	${echo} ""
	${chown} -R www-data:www-data $folder
	${find} $folder/ -type d -exec ${chmod} 750 {} \;
	${find} $folder/ -type f -exec ${chmod} 640 {} \;
	${sudo} -u www-data php $folder/occ maintenance:mode --off
	${echo} ""
	${echo} "upgrade nextcloud"
	${echo} ""
	${sudo} -u www-data php $folder/occ upgrade -vv
	${sudo} -u www-data php $folder/occ db:add-missing-columns
	${sudo} -u www-data php $folder/occ db:add-missing-indices
	${sudo} -u www-data php $folder/occ db:add-missing-primary-keys
	${sudo} -u www-data php $folder/occ app:update --all
	${sudo} -u www-data php $folder/occ maintenance:theme:update
	# not longer needed		${sudo} -u www-data php $folder/occ maintenance:repair --include-expensive
	${echo} ""
	${echo} "start cron"
	${systemctl} start cron
	${rm} nextcloud-$version.zip
	# If the remove flag is set, run the removal command
	if [ "$remove_bkpfolder" = true ]; then
	    echo "Removing folder: $folder"
	    rm -rf "$folder"
	    if [ $? -eq 0 ]; then
	        echo "Folder removed successfully."
	    else
	        echo "Failed to remove folder." >&2
	    fi
	fi
	${echo} ""
	${echo} "Update done at $(date '+%d-%m-%Y %H:%M:%S')"
	${echo} ""
fi
exit 0
