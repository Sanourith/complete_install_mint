#! /bin/bash



##############################
## DESINSTALLER UN LOGICIEL ##
##############################
logiciel="opera-gx-stable"
sudo apt remove $logiciel
sudo apt autoremove
sudo apt purge $logiciel

# + check cache de l'app
ls ~/.config | grep $logiciel # vérifie l'existence de la config
rm -rf ~/.config/$logiciel
rm -rf ~/.cache/$logiciel
