#!/bin/bash
# running as root?
clear
set -e
if [ "$(id -u)" != "0" ]; then
	echo
	echo "Please run as root!"
	echo 
	exit 1
fi
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
# Date
dt=$(${date} '+%d-%m-%Y')
# Variables
folder=$1
version=$2
folder_bkp="$folder"_bkp_"$dt"
# Logfile
exec > >(tee -i -a "/var/log/nextcloud/$folder_bkp-nextcloudupdate.log")
exec 2>&1
# Check if folder and version is set
if [[ -z "$folder" ]] || [[ -z "$version" ]]
then
      ${echo} ""
      ${echo} "Folder info or nextcloud version number is missing"
      ${echo} ""
      exit 1
else
    if !  ${grep} -q "'version' => '$version'" "$folder/config/config.php"
    then
	# main
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
	${rm} -rf $folder_bkp
	${echo} ""
	${echo} "Update done at $(date '+%d-%m-%Y %H:%M:%S')"
	${echo} ""
    else
	${echo} ""
	${echo} "version $version is allready installed"
	${echo} ""
    fi
fi
exit 0
