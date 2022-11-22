#set stop error
set -e
dt=$(date '+%m-%d-%Y')
folder=$1
version=$2
folder_bkp="$folder"_bkp_"$dt"
if [[ `ps -acx|grep apache|wc -l` > 0 ]]; then
    echo "Configured with Apache"
        webservice="apache2"
fi
if [[ `ps -acx|grep nginx|wc -l` > 0 ]]; then
    echo "Configured with Nginx"
        webservice="nginx"
fi
if [ -z "$folder" ]
then
      echo "folder info is missing"
      exit
else
        if [ -z "$version" ]
        then
                echo "NextcloudVersionsnumber is missing"
                exit
        else
                if !  grep -q "'version' => '$version" "$folder/config/config.php"
                then
                        if ! grep -q "'maintenance' => true" "$folder/config/config.php"
                        then
                        echo "everything is fine"
                                set -x
                                mv $folder "$folder_bkp"
                                if ! find nextcloud-$version.zip
                                then
                                  wget https://download.nextcloud.com/server/releases/nextcloud-$version.zip
                                  unzip nextcloud-$version 
                                else 
                                  unzip nextcloud-$version
                                fi
                                systemctl stop $webservice
                                if ! $folder=nextcloud
                                then
                                mv nextcloud $folder
                                fi
                                cp "$folder_bkp"/config/config.php $folder/config/config.php
                                chown -R www-data:www-data $folder;
                                find $folder/ -type d -exec chmod 750 {} \;
                                find $folder/ -type f -exec chmod 640 {} \;
                                systemctl start $webservice
                                sudo -u www-data php $folder/occ upgrade
                                sudo -u www-data php $folder/occ db:add-missing-indices
                                sudo -u www-data php $folder/occ db:add-missing-primary-keys
                                sudo -u www-data php $folder/occ db:add-missing-columns
                                sudo -u www-data php $folder/occ app:update --all
                                sudo -u www-data php $folder/occ maintenance:repair
                        else
                                echo "Nextcloud is in the maintance mode"
                        fi
                else
                                echo "version $version is allready installed"
                fi
        fi
fi
exit
