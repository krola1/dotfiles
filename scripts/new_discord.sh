#!/bin/bash

sudo rm /opt/discord-*tar.gz
sudo rm -r /opt/Discord
sudo cp "$(ls -t ~/Downloads/discord-*.tar.gz | head -1)" /opt
sudo tar xvzf /opt/discord-*.tar.gz -C /opt/
sudo sed -i 's:^Exec=.*:Exec=/opt/Discord/Discord:' /opt/Discord/discord.desktop
sudo rm /usr/share/applications/discord.desktop
sudo ln -s /opt/Discord/discord.desktop /usr/share/applications/
