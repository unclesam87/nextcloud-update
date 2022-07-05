set -e
#set stop error
dt=(date '+%m-%d-%Y')
folder=$1
version=$2
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
      echo "Ordner Angabe fehlt"
      exit
else
        if [ -z "$version" ]
        then
                echo "NextcloudVersionsnummer fehlt"
                exit
        else
                if !  grep -q "'version' => '$version" "$folder/config/config.php"
                then
                        if ! grep -q "'maintenance' => true" "$folder/config/config.php"
                        then
                        echo "Alles gut - es geht los"
                                set -x
                                mv $folder "$folder"_bkp
                                if ! find nextcloud-$version.zip
                                then
                                  wget https://download.nextcloud.com/server/releases/nextcloud-$version.zip
                                  unzip nextcloud-$version
                                else 
                                  unzip nextcloud-$version
                                fi
                                systemctl stop $webservice
                                mv nextcloud $folder
                                cp "$folder"_bkp/config/config.php $folder/config/config.php
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
                                echo "Nextcloud noch im Maintance Mode"
                        fi
                else
                                echo "Version $version ist schon installiert"
                fi
        fi
fi
exit
