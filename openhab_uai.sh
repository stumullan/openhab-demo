#!/bin/bash

# Edit to match your settings
username="openhab"
password="openhab"

# Update these as necessary
runtime="https://bintray.com/artifact/download/openhab/bin/distribution-1.8.3-runtime.zip"
addons="https://bintray.com/artifact/download/openhab/bin/distribution-1.8.3-addons.zip"
demo="https://bintray.com/artifact/download/openhab/bin/distribution-1.8.3-demo.zip"

runtime_file=${runtime##https:/*/}
addons_file=${addons##https:/*/}
demo_file=${demo##https:/*/}

clear
echo "Starting unattended install of openHAB demo on a Rasppberry Pi"
echo "... requires DietPi or raspbian installed with user: $username and password: $password"

if [ $UID -ne 0 ] 
then
        echo -e "Error: Run script as sudo: sudo bash ./openhab_uai.sh "
        exit
fi

# doesn't seem to matter if init.d or systemd is used, both can be active
# I was going to modify to cover both init and systemd cases and exit on other
# i=$(ps -p 1 -o comm=)
# if [ $i = "systemd" ] 
# then
# 	echo "Raspberry Pi is running systemd"
# elif [ $i = "init" ]
# then
# 	echo "Raspberry Pi is not running systemd"
# 	exit 1
# else
# 	echo "Raspberry Pi is not running systemd or init"
# 	exit 1
# fi

echo "Check home directory"
c=$(pwd)
if [ "$c" != "/home/pi" ]
then
	echo "Error: The unattended install runs on dietpi or raspbian"
	echo "and requires user: pi with home directory: /home/pi and not $c"
	echo "Failed to install"
	exit 1
fi

echo "Update available packages and their versions"
sudo apt-get update -y
if [ $? -ne 0 ]
then
	echo "Error: Failed apt-get update"
	exit $?
fi

echo "Upgrade before installing new packages"
sudo apt-get upgrade -y
if [ $? -ne 0 ]
then
	echo "Error: Failed apt-get upgrade"
	exit $?
fi

echo "Install java 8, if already installed it will skip"
sudo apt-get install oracle-java8-jdk -y 
if [ $? -ne 0 ]
then
	echo "Error: Failed install of java8"
	exit $?
fi

echo "Install eclipse"
sudo apt-get install eclipse -y
if [ $? -ne 0 ]
then
	echo "Error: Failed install of eclipse"
	exit $?
fi

echo "Install mosquitto"
echo "... get key"
wget http://repo.mosquitto.org/debian/mosquitto-repo.gpg.key 
if [ $? -ne 0 ]
then
	echo "Error: Failed get of mosquitto key"
	exit $?
fi

echo "... add apt-key"
sudo apt-key add mosquitto-repo.gpg.key
if [ $? -ne 0 ]
then
	echo "Error: Failed adding mosquitto key"
	exit $?
fi

echo "... remove key file"
rm mosquitto-repo.gpg.key
if [ $? -ne 0 ]
then
	echo "Error: Failed removing mosquitto key"
	exit $?
fi

echo "... change to sources directory"
cd /etc/apt/sources.list.d/
if [ $? -ne 0 ]
then
	echo "Error: Failed to changes to apt sources directory"
	exit $?
fi

echo "... get mosquitto for jessie"
sudo wget http://repo.mosquitto.org/debian/mosquitto-jessie.list
if [ $? -ne 0 ]
then
	echo "Error: Failed to get mosquitto"
	exit $?
fi

echo "... install mosquitto"
sudo apt-get install mosquitto mosquitto-clients -y
if [ $? -ne 0 ]
then
	echo "Error: Failed to install mosquitto"
	exit $?
fi

echo "Make openHAB directory"
sudo mkdir /opt
sudo mkdir /opt/openhab
sudo mkdir /opt/openhab/addons
sudo chmod -R ugo+rw /opt/openhab
cd /opt/openhab

echo "Download openHAB runtime"
echo "... get openhab runtime"
sudo wget $runtime
if [ $? -ne 0 ]
then
	echo "Error: Failed to get openhab runtime"
	exit $?
fi
sudo unzip $runtime_file
sudo rm $runtime_file

echo "Download openHAB addons"
echo "... get openhab addons"
cd /opt/openhab/addons
sudo wget $addons
if [ $? -ne 0 ]
then
	echo "Error: Failed to get openhab addons"
	exit $?
fi
sudo unzip $addons_file
sudo rm $addons_file

echo "Download openHAB demo"
echo "... get openhab demo"
cd /opt/openhab
sudo wget $demo
if [ $? -ne 0 ]
then
	echo "Error: Failed to get openhab demo"
	exit $?
fi
sudo unzip -o $demo_file 
sudo rm $demo_file

echo "Change start script to be executable"
cd /opt/openhab
sudo chmod +x start.sh
if [ $? -ne 0 ]
then
	echo "Error: Failed to change permissions on start.sh"
	exit $?
fi

echo "Recursively set permissions on openHAB directories"
sudo chmod -R ugo+rw /opt/openhab
if [ $? -ne 0 ]
then
	echo "Error: Failed to change permissions on openhab directories"
	exit $?
fi

echo "Create openHAB users config"
sudo echo "user=password,user,role" > /opt/openhab/configurations/users.cfg
sudo echo "$username=$password" >> /opt/openhab/configurations/users.cfg
if [ $? -ne 0 ]
then
	echo "Error: Failed to write users.cfg properly"
	exit $?
fi

echo "Add MQTT binding"
sudo cp /opt/openhab/configurations/openhab_default.cfg /opt/openhab/configurations/openhab.cfg

echo "Uncomment config settings"
sed -i '/mqtt:broker.url=tcp:\/\/localhost:1883/s/^#//g' /opt/openhab/configurations/openhab.cfg
sed -i '/mqtt:broker.clientId=openhab/s/^#//g' /opt/openhab/configurations/openhab.cfg 

echo "Make system directory"
sudo mkdir /usr/lib/systemd
sudo mkdir /usr/lib/systemd/system 
sudo rm /usr/lib/systemd/system/openhab.service

echo "Create a start-up file"
sudo echo "[Unit]" > /usr/lib/systemd/system/openhab.service
sudo echo "Description=openHAB Home Automation Bus" >> /usr/lib/systemd/system/openhab.service
sudo echo "Documentation=http://www.openhab.org" >> /usr/lib/systemd/system/openhab.service
sudo echo "Wants=network-online.target" >> /usr/lib/systemd/system/openhab.service
sudo echo -e "After=network-online.target\n" >> /usr/lib/systemd/system/openhab.service
sudo echo "[Service]" >> /usr/lib/systemd/system/openhab.service
sudo echo "Type=simple" >> /usr/lib/systemd/system/openhab.service
sudo echo "GuessMainPID=yes" >> /usr/lib/systemd/system/openhab.service
sudo echo "User=pi" >> /usr/lib/systemd/system/openhab.service
sudo echo "ExecStart=/opt/openhab/start.sh" >> /usr/lib/systemd/system/openhab.service
sudo echo -e "ExecStop=kill -SIGINT \$MAINPID" >> /usr/lib/systemd/system/openhab.service
sudo echo "Restart=on-failure" >> /usr/lib/systemd/system/openhab.service
sudo echo -e "WorkingDirectory=/opt/openhab\n" >> /usr/lib/systemd/system/openhab.service
sudo echo "[Install]" >> /usr/lib/systemd/system/openhab.service
sudo echo "WantedBy=multi-user.target" >> /usr/lib/systemd/system/openhab.service
if [ $? -ne 0 ]
then
	echo "Error: Failed to write systemd service properly"
	exit $?
fi

echo "Change owner recursively on openhab"
sudo chown -R pi:pi /opt/openhab
if [ $? -ne 0 ]
then
	echo "Error: Change owner on openhab to pi"
	exit $?
fi

echo "Reload systemd so daemon is aware of new configuration"
sudo systemctl --system daemon-reload
cd /usr/lib/systemd/system
sudo systemctl enable openhab.service
sudo systemctl start openhab.service 

echo -e "openHAB demo successfully installed!\n"
echo "Reboot Raspberry Pi with command: sudo reboot"
echo "Rebooting Raspberry Pi and starting openHAB takes about 5 minutes"
echo "After waiting 5 minutes, open browser and enter the following in URL"
echo "   http://?raspberry-pi-ip?:8080/openhab.app?sitemap=demo"
exit 0
