#! /bin/bash

#####################################
## PREPARATION SAUVEGARDE COMPLETE ##
#####################################
# Si besoin, monter le disque dur :
sudo mkdir -p /mnt/sanoudde
sudo mount -t ntfs-3g /dev/sda1 /mnt/sanoudde
# Démonter le disque après usage
sudo umount /mnt/sanoudde

path_1="/media/sanou/SSD4OWL/"
path_2="/media/sanou/SanouDDE/"
rsync -ah --info=progress2 $path_1 $path_2

##############################
## DESINSTALLER UN LOGICIEL ##
##############################
logiciel="webstorm"
apt list --installed | grep $logiciel
dpkg -l | grep -i $logiciel

sudo apt remove $logiciel
sudo apt autoremove
sudo apt purge $logiciel

# + check cache de l'app
ls ~/.config | grep $logiciel # vérifie l'existence de la config
rm -rf ~/.config/$logiciel
rm -rf ~/.cache/$logiciel
