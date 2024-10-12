# nextcloud-update
Simple Nextcloud Update Script

as i had several problems with upgrading over the webgui, i switched to the terminal. for this is this small script. 
tips and improvements are more then welcomed so feel free to open an issue

## how to use:
 1. download script
 2.  chmod +x 
 3.  use script:
 ```
    nextcloud-update.sh -v versionnumber -f pathtonextcloudfolder -r (when u wanna delete the backup folder afterwards)
 ```
example:
```
    nextcloud-update.sh -v 29.0.8 -f /var/www/nextcloud -r
 ```
