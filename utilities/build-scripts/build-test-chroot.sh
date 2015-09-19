#!/bin/bash
# -------------------------------------------------------------------------------
# Author: 	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-test-chroot.sh
# Script Ver:	0.5.6
# Description:	Builds a Debian / SteamOS chroot for testing 
#		purposes. based on repo.steamstatic.com
#               See: https://wiki.debian.org/chroot
#
# Usage:	sudo ./build-test-chroot.sh [type] [release]
# Options:	types: [debian|steamos] 
#		releases debian:  [wheezy|jessie]
#		releases steamos: [alchemist|alchemist-beta|brewmaster|brewmaster-beta]
#		
# Help:		sudo ./build-test-chroot.sh --help for help
#
# Warning:	You MUST have the Debian repos added properly for
#		Installation of the pre-requisite packages.
#
# See Also:	https://wiki.debian.org/chroot
# -------------------------------------------------------------------------------

# set $USER since we run as root/sudo
# The reason for running sudo is do to the post install commands being inside the chroot
# Rather than run into issues adding user(s) to /etc/sudoers, we will run elevated.

export USER="$SUDO_USER"
#echo "user test: $USER"
#exit 1


# remove old custom files
rm -f "log.txt"

# set arguments / defaults
type="$1"
release="$2"
target="${type}-${release}"
stock_choice=""

show_help()
{
	
	clear
	
	cat <<-EOF
	Warning: usage of this script is at your own risk!
	
	Usage
	---------------------------------------------------------------
	sudo ./build-test-chroot.sh [type] [release]
	Types: [debian|steamos] 
	Releases (Debian):  [wheezy|jessie]
	Releases (SteamOS): [alchemist|alchemist-beta|brewmaster|brewmaster-beta]
	
	Plese note that the types wheezy and jessie belong to Debian,
	and that brewmaster belong to SteamOS.

	EOF
	exit
	
}

check_sources()
{
	
	# Debian sources are required to install xorriso for Stephenson's Rocket
	sources_check1=$(sudo find /etc/apt -type f -name "jessie*.list")
	sources_check2=$(sudo find /etc/apt -type f -name "wheezy*.list")
	
	if [[ "$sources_check1" == "" && "$sources_check2" == "" ]]; then
	
		echo -e "\n==WARNING==\nDebian sources are needed for building chroots, add now? (y/n)"
		read -erp "Choice: " sources_choice
	
		if [[ "$sources_choice" == "y" ]]; then
	
			../add-debian-repos.sh
			
		elif [[ "$sources_choice" == "n" ]]; then
		
			echo -e "Sources addition skipped"
		
		fi
		
	fi
	
	
}


funct_prereqs()
{
	
	echo -e "==> Installing prerequisite packages\n"
	sleep 1s
	
	# Install the required packages 
	apt-get install binutils debootstrap debian-archive-keyring
	
}

funct_set_target()
{
	
	# setup targets for appropriate details
	if [[ "$type" == "debian" ]]; then
	
		target_URL="http://http.debian.net/debian"
	
	elif [[ "$type" == "steamos" ]]; then
		
		target_URL="http://repo.steampowered.com/steamos"
	
	elif [[ "$type" == "steamos-beta" ]]; then
	
		target_URL="http://repo.steampowered.com/steamos"
	
	elif [[ "$type" == "--help" ]]; then
		
		show_help
	
	fi

}

function gpg_import()
{
	# When installing from wheezy and wheezy backports,
	# some keys do not load in automatically, import now
	# helper script accepts $1 as the key
	
	# Key Desc: Debian Archive Automatic Signing Key
	# Key ID: 2B90D010
	# Full Key ID: 7638D0442B90D010
	gpg_key_check=$(gpg --list-keys 2B90D010)
	
	# check for key
	if [[ "$gpg_key_check" != "" ]]; then
		echo -e "\nDebian Archive Automatic Signing Key [OK]"
		sleep 1s
	else
		echo -e "\nDebian Archive Automatic Signing Key [FAIL]. Adding now..."
		gpg --no-default-keyring --keyring /usr/share/keyrings/debian-archive-keyring.gpg \
		--recv-keys 7638D0442B90D010
	fi
	
	# Key Desc: Valve SteamOS Release Key <steamos@steampowered.com>
	# Key ID: 8ABDDD96
	# Full Key ID: F28029BB103C02AE
	gpg_key_check=$(gpg --list-keys 8ABDDD96)
	
	# check for key
	if [[ "$gpg_key_check" != "" ]]; then
		echo -e "\nValve SteamOS Release Key [OK]"
		sleep 1s
	else
		echo -e "\nValve SteamOS Release Key [FAIL]. Adding now..."
		gpg --no-default-keyring --keyring /usr/share/keyrings/debian-archive-keyring.gpg \
		--recv-keys F28029BB103C02AE
	fi

}

funct_create_chroot()
{
	#echo -e "\n==> Importing GPG keys\n"
	#sleep 1s
	
	if [[ "$type" == "steamos" || "$type" == "steamos-beta" ]]; then
		
		# import GPG key
		# gpg_import
		:
		
	fi
	
	# create our chroot folder
	if [[ -d "/home/$USER/chroots/${target}" ]]; then
	
		# remove DIR
		rm -rf "/home/$USER/chroots/${target}"
		
	else
	
		mkdir -p "/home/$USER/chroots/${target}"
		
	fi
	
	# build the environment
	echo -e "\n==> Building chroot environment...\n"
	sleep 1s
	
	# debootstrap
	if [[ "$type" == "steamos" || "$type" == "steamos-beta" ]]; then
	
		# handle SteamOS
		/usr/sbin/debootstrap --keyring="/usr/share/keyrings/valve-archive-keyring.gpg" \
		--arch i386 ${release} /home/$USER/chroots/${target} ${target_URL}
		
	else
	
		# handle Debian instead
		/usr/sbin/debootstrap --arch i386 ${release} /home/$USER/chroots/${target} ${target_URL}
		
	fi
	
	echo -e "\n==> Configuring"
	sleep 1s
	
	# add to fstab
	# TODO
	fstab_check=$(cat /etc/fstab | grep ${target})
	if [[ "$fstab_check" == "" ]]; then
	
		# Mount proc and dev filesystem (add to **host** fstab)
		sudo su -c "echo '#chroot ${target}' >> /etc/fstab"
		sudo su -c "echo '/dev/pts /home/$USER/chroots/${target}/dev/pts none bind 0 4' >> /etc/fstab"
		sudo su -c "echo 'proc /home/$USER/chroots/${target}/proc proc defaults 0 4' >> /etc/fstab"
		sudo su -c "echo 'sysfs /home/$USER/chroots/${target}/sys sysfs defaults 0 4' >> /etc/fstab"
		
	fi
	
	# set script dir and enter
	script_dir=$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)
	cd $script_dir
	
	# copy over post install scripts for execution
	echo -e "\n==> Copying post install scripts to tmp directory\n"
	
	cp -v "chroot-post-install.sh" "/home/$USER/chroots/${target}/tmp/"
	cp -v "gpg_import.sh" "/home/$USER/chroots/${target}/tmp/"
	
	# mark executable
	chmod +x "/home/$USER/chroots/${target}/tmp/chroot-post-install.sh"
	chmod +x "/home/$USER/chroots/${target}/tmp/gpg_import.sh"

	# modify gpg_import.sh with sudo removed, as it won't be configured and we
	# don't need it to be there
	sed -i "s|sudo ||g" "/home/$USER/chroots/${target}/tmp/gpg_import.sh"

	# Modify type based on opts
	sed -i "s|"tmp_type"|${type}|g" "/home/$USER/chroots/${target}/tmp/chroot-post-install.sh"
	
	# Change opt-in based on opts
	# sed -i "s|"tmp_beta"|${beta_flag}|g" "/home/$USER/chroots/${target}/tmp/chroot-post-install.sh"
	
	# modify release_tmp for Debian Wheezy / Jessie in post-install script
	sed -i "s|"tmp_release"|${release}|g" "/home/$USER/chroots/${target}/tmp/chroot-post-install.sh"
	
	# create alias file that .bashrc automatically will source
	if [[ -f "/home/$USER/.bash_aliases" ]]; then
	
		# do nothing
		echo -e "\nBash alias file found, skipping creation."
	else
	
		echo -e "\nBash alias file not found, creating."
		# create file
		touch "/home/$USER/.bash_aliases"

	fi
	
	# create alias for easy use of command
	alias_check=$(cat "/home/$USER/.bash_aliases" | grep chroot-${target})

	
	if [[ "$alias_check" == "" ]]; then
	
		cat <<-EOF >> "/home/$USER/.bash_aliases"
		
		# chroot alias for ${type} (${target})
		alias chroot-${target}='sudo /usr/sbin/chroot /home/desktop/chroots/${target}'
		EOF
	
	fi
	
	# source bashrc to update.
	# bashrc should source /home/$USER/.bash_aliases
	# can't source form .bashrc, since they use ~ instead of $HOME
	# source from /home/$USER/.bash_aliases instead
	
	#source "/home/$USER/.bashrc"
	source "/home/$USER/.bash_aliases"
	
	# enter chroot to test
	cat <<-EOF
	
	------------------------------------------------------------
	Summary
	------------------------------------------------------------
	EOF

	echo -e "\nYou will now be placed into the chroot. Press [ENTER].
If you wish  to leave out any post operations and remain with a 'stock' chroot, type 'stock',
then [ENTER] instead. A stock chroot is only intended and suggested for the Debian chroot type."
	
	echo -e "You may use 'sudo /usr/sbin/chroot /home/desktop/chroots/${target}' to 
enter the chroot again. You can also use the newly created alias listed below\n"

	echo -e "\tchroot-${target}\n"
	
	# Capture input
	read stock_choice
	
	if [[ "$stock_choice" == "" ]]; then
	
		# Captured carriage return / blank line only, continue on as normal
		# Modify target based on opts
		sed -i "s|"tmp_stock"|"no"|g" "/home/$USER/chroots/${target}/tmp/chroot-post-install.sh"
		#printf "zero length detected..."
		
	elif [[ "$stock_choice" == "stock" ]]; then
	
		# Modify target based on opts
		sed -i "s|"tmp_stock"|"yes"|g" "/home/$USER/chroots/${target}/tmp/chroot-post-install.sh"
		
	elif [[ "$stock_choice" != "stock" ]]; then
	
		# user entered something arbitrary, exit
		echo -e "\nSomething other than [blank]/[ENTER] or 'stock' was entered, exiting.\n"
		exit
	fi
	
	# "bind" /dev/pts
	mount --bind /dev/pts "/home/$USER/chroots/${target}/dev/pts"
	
	# run script inside chroot with:
	# chroot /chroot_dir /bin/bash -c "su - -c /tmp/test.sh"
	/usr/sbin/chroot "/home/$USER/chroots/${target}" /bin/bash -c "/tmp/chroot-post-install.sh"
	
	# Unmount /dev/pts
	umount /home/$USER/chroots/${target}/dev/pts
	
}

main()
{
	clear
	check_sources
	funct_prereqs
	funct_set_target
	funct_create_chroot
	
}

#####################################################
# Main
#####################################################

# Warn user script must be run as root
if [ "$(id -u)" -ne 0 ]; then

	clear
	
	cat <<-EOF
	==ERROR==
	Script must be run as root! Try:
	
	sudo $0 [type] [release]
	
	EOF
	
	exit 1
	
fi

# shutdown script if type or release is blank
if [[ "$type" == "" || "$release" == "" ]]; then

	clear
	echo -e "==ERROR==\nType or release not specified! Dying...\n"
	exit 1
fi

# Start main script if above checks clear
main | tee log_temp.txt

#####################################################
# cleanup
#####################################################

# convert log file to Unix compatible ASCII
strings log_temp.txt > log.txt

# strings does catch all characters that I could 
# work with, final cleanup
sed -i 's|\[J||g' log.txt

# remove file not needed anymore
rm -f "custom-pkg.txt"
rm -f "log_temp.txt"
