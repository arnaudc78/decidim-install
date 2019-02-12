#!/bin/bash
#
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

echo -e "***********************************************************************"
echo -e "* \e[31mWARNING:\e[0m                                                 *"
echo -e "* This program will try to install automatically Decidim and all      *"
echo -e "* related software. This includes Nginx, Passenger, Ruby and other.   *"
echo -e "* \e[33mUSE IT ONLY IN A FRESHLY INSTALLED UBUNTU 18.04 SYSTEM\e[0m   *"
echo -e "* No guarantee whatsoever that it won't break your system!            *"
echo -e "*                                                                     *"
echo -e "* (c) Ivan Vergés <ivan (at) platoniq.net>                            *"
echo -e "* https://github.com/Platoniq/decidim-install                         *"
echo -e "*                                                                     *"
echo -e "***********************************************************************"

set -e

info() {
	echo -e "$1"
}
yellow() {
	echo -e "\e[33m$1\e[0m"
}
green() {
	echo -e "\e[32m$1\e[0m"
}
red() {
	echo -e "\e[31m$1\e[0m"
}
exit_help() {
	info "\nUsage:"
	info " $0 [options]\n"
	info "Installs Decidim and all necessary dependencies in Ubuntu 18.04\n"
	info "This script tries to be idempotent (ie: it can be run repeatedly)\n"
	info "Options:"
	info " -y          Do not ask for confirmation to run the script"
	info " -h          Show this help"
	info " -s[step]    Skip the [step] specified. Multiple steps can be"
	info "             specified with several -s options\n"
	info "             Valid steps are (in order of execution):"
	info "              check     Check if we are using Ubuntu 18.04"
	info "              prepare   Update system, configure timezone"
	info "              rbenv     Install ruby through rbenv"
	trap - EXIT
	exit
}
abort() {
	red "Aborted by the user!"
	trap - EXIT
	exit
}
cleanup() {
	rv=$?
	if [ "$rv" -ne 0 ]; then
		red "Something went wrong! Aborting!"
		exit $rv
	else
		green "Finished successfully!"
	fi
}

step_check() {
	green "Checking current system..."
	if [ "$EUID" -eq 0 ]; then
		red "Please do not run this script as root"
		info "User a normal user with sudo permissions"
		info "sudo password will be asked when necessary"
		exit 1
	fi
	if [ $(awk -F= '/^ID=/{print $2}' /etc/os-release) != "ubuntu" ]; then
		red "Not an ubuntu system!"
		exit 1
	fi
	if [ $(awk -F= '/^VERSION_ID=/{print $2}' /etc/os-release) != "18.04" ]; then
		red "Not ubuntu 18.04!"
		exit 1
	fi
}

step_prepare() {
	green "Updating system"
	sudo apt update
	sudo apt -y upgrade
	sudo apt -y autoremove
	green "Configuring timezone"
	sudo dpkg-reconfigure tzdata
	green "Installing necessary software"
	sudo apt-get -y install autoconf bison build-essential libssl-dev libyaml-dev \
		 libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm-dev
}

step_rbenv() {
	# pause EXIT trap
	trap - EXIT

	info "Installing rbenv"
	if [ -d "$HOME/.rbenv" ]; then
		yellow "$HOME/.rbenv already exists!"
	else
		info "Installing rbenv from GIT"
		git clone https://github.com/rbenv/rbenv.git $HOME/.rbenv
	fi
	if grep -Fxq 'export PATH="$HOME/.rbenv/bin:$PATH"' "$HOME/.bashrc" ; then
		yellow "$HOME/.rbenv/bin already in PATH"
	else
		info "Installing $HOME/.rbenv/bin in PATH"
		echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> "$HOME/.bashrc"
	fi
	if grep -Fxq 'eval "$(rbenv init -)"' "$HOME/.bashrc" ; then
		yellow "rbenv init already in bashrc"
	else
		info "Installing rbenv init in bashrc"
		echo 'eval "$(rbenv init -)"' >> "$HOME/.bashrc"
	fi
	source "$HOME/.bashrc"
	if rbenv version | grep -Fq ".rbenv/version"; then
		green "rbenv successfully installed"
	else
		red "Something went wrong installing rbenv."
		red "rbenv does not appear to be a bash function"
		info "You might want to perform this step manually"
		type rbenv
		exit 1
	fi

	# resume EXIT trap
	trap cleanup EXIT
}

STEPS=("check" "prepare" "rbenv")
SKIP=
install() {
	for i in "${!STEPS[@]}"; do
		step=${STEPS[i]}
		if [[ " ${SKIP[*]} " == *" $step "* ]]; then
			red "Skipping step $i: $step"
		else
			yellow "Step $i: $step "
			"step_$step"
		fi
	done
}

start() {
	trap cleanup EXIT
	trap abort INT TERM
	install
}

confirm() {
	while true; do
	    read -p "Do you wish to continue? [y/N]" yn
	    case $yn in
	        [Yy]* ) start; break;;
	        [Nn]* ) exit;;
	        * ) abort;;
	    esac
	done
}

CONFIRM=1
while getopts yhs: option; do
	case "${option}" in
		y ) yellow "No asking for confirmation"; CONFIRM=0;;
		h ) exit_help;;
		s ) SKIP+=("$OPTARG");;
	esac
done

if [ "$CONFIRM" == "1" ]; then
	confirm
else
	start
fi

