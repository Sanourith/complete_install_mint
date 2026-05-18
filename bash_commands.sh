#! /bin/bash



##############################
## DESINSTALLER UN LOGICIEL ##
##############################
logiciel="opera-gx-stable"
sudo apt remove $logiciel
sudo apt autoremove
sudo apt purge $logiciel

# + check cache de l'app
rm -rf ~/.config/opera-gx
rm -rf ~/.cache/opera-gx
