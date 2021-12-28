#!/usr/bin/env bash

# e - script stops on error
# u - error if undefined variable
# o pipefail - script fails if command piped fails
#set -euo pipefail

# INCLUDES
source ./install_config

run() {
    local dry_run=${dry_run:-false}
    local output=${output:-/dev/tty2}

    while getopts d:o: option
    do
        case "${option}"
            in
            d) dry_run=${OPTARG};;
            o) output=${OPTARG};;
            *);;
        esac
    done

    log INFO "DRY RUN? $dry_run" "$output"

    check_sudo

    install-dialog

    dialog-welcome

    # if no install_conf download default
    if [ ! -f "./install_config" ]; then
        wget "https://raw.githubusercontent.com/MarioWi/MultiCraft-JAR-Conf/master/install_config"
        source ./install_config
    fi

    check-file "install_config"

    check-file "versions.csv"

    check-file "update.sh"

    log INFO "CHOOSE SERVER" "$output"
    dialog-choose-server srv
    choicesSrv=$(cat srv) && rm srv

    log INFO "SERVER CHOOSEN: $choicesSrv" "$output"
    servers="$(extract-choosed-servers "$choicesSrv" "versions.csv")"

    log INFO "CHOOSE VERSIONS" "$output"
    dialog-choose-versions "vers" "$choicesSrv" "$servers"

    extract-choosed-versions "versions.csv" "choosedVersions.csv"

    log INFO "CHOOSE GROUP:USER" "$output"
    dialog-choose-user "user"

    log INFO "CHOOSE RIGHTS" "$output"
    dialog-choose-rights "rights"

    log INFO "INSTALL CHOOSED VERSIONS" "$output"
    dialog-install-confs
    install_choosed_versions "choosedVersions.csv"

    cleanup

    dialog-installed

    clear

}

log() {
    local -r level=${1:?}
    local -r message=${2:?}
    local -r output=${3:?}
    local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    echo -e "${timestamp} [${level}] ${message}" >>"$output"
}

check_sudo(){
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root" 
        exit 1
    fi
}

check-file(){
    log INFO "CHECK IF $1 ALREADY EXISTS" "$output"
    if [ ! -f ${1:?} ]
    then
        download-file "$1"
        log INFO "$1 DOWNLOADED" "$output"
    fi
}

download-file(){
    curl "$installer_url/$1" > "./$1"
    log INFO "$1 DOWNLOADED AT: $installer_url/$1" "$output"
}

install-dialog() {

    command -v "dialog" >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        sudo apt-get update -y && sudo apt-get upgrade -y
        sudo apt-get install dialog -y
    fi
}

dialog-welcome() {
    dialog --backtitle "Multicraft - JAR Config" --title "Welcome!" --msgbox "Welcome to the Multicraft JAR-Conf downloader.\n" 10 60
}

dialog-choose-server(){
    local file=${1:?}

    server=(
        "vanilla" "Vanilla" on
        "spigot" "Spigot" on
        "paperspigot" "PaperSpigot" on
        "custom" "Custom" off)

    dialog --backtitle "Multicraft - JAR Config" --title "Choose Server" --checklist "You can now choose the groups of Server/APIs you want to install, according to your own CSV file.\n\nPress SPACE to select and ENTER to validate your choices." 0 0 0 "${server[@]}" 2> "$file"

    exitstatus=$?
    if [ ! $exitstatus = 0 ]; then
        log INFO "CANCELD CHOOSE SERVER" "$output"
        cleanup
        exit 1
    fi
}

extract-choosed-servers(){
    local -r choices=${1:?}
    local -r versions_path=${2:?}

    selection="^$(echo $choices | sed -e 's/ /,|^/g'),"
    lines=$(grep -E "$selection" "$versions_path")

    echo "$lines"
}

dialog-choose-versions(){
    local file="${1:?}"
    local -r choices="${2:?}"
    local -r servers="${3:?}"

    array=()

    for srv in $choices; do
        unset array[@]
        i=1 #Index counter for adding to array

        selection="^$(echo $srv | sed -e 's/ /,|^/g'),"
        lines=$(echo "$servers" | grep -w "$srv")
        for k in $lines; do
            version=$(echo $k | awk -F ',' '{print $2;}')
            array[ $i ]=$version
            # check if custom server
            if [[ "$srv" == "custom" ]]; then
                # check if jar installed
                if [ ! -f "$jar_path/$version.jar" ]; then
                    # check if conf installed
                    if [ ! -f "$jar_path/$version.jar.conf" ]; then
						array[ $i + 1]=$version.jar.conf
						array[ ($i + 2) ]=off
					else
						array[ $i + 1]="$version.jar.conf (conf existing)"
						array[ ($i + 2) ]=off
					fi
				else
                    # check if conf installed
                    if [ ! -f "$jar_path/$version.jar.conf" ]; then
						array[ $i + 1]="$version.jar.conf (jar existing)"
						array[ ($i + 2) ]=on
					else
						array[ $i + 1]="$version.jar.conf (jar & conf existing)"
						array[ ($i + 2) ]=off
					fi
				fi
			else
                # check if jar installed
                if [ ! -f "$jar_path/$srv-$version.jar" ]; then
                    # check if conf installed
                    if [ ! -f "$jar_path/$srv-$version.jar.conf" ]; then
						array[ $i + 1]=$srv-$version.jar.conf
						array[ ($i + 2) ]=off
					else
						array[ $i + 1]="$srv-$version.jar.conf (conf existing)"
						array[ ($i + 2) ]=off
					fi
				else
                    # check if conf installed
                    if [ ! -f "$jar_path/$srv-$version.jar.conf" ]; then
						array[ $i + 1]="$srv-$version.jar.conf (jar existing)"
						array[ ($i + 2) ]=on
					else
						array[ $i + 1]="$srv-$version.jar.conf (jar & conf existing)"
						array[ ($i + 2) ]=off
					fi
				fi
			fi
            (( i=($i+3) ))
        done

        dialog --backtitle "Multicraft - JAR Config" --title "Choose Version for $srv" --checklist "You can now choose the groups of Versions you want to install for $srv, according to your own CSV file.\n\nPress SPACE to select and ENTER to validate your choices." 0 0 0 "${array[@]}" 2> "$srv"
        versions=$(cat $srv)
        if [ "$versions" = "" ]; then
            rm $srv
        fi

        log INFO "VERSIONS CHOOSEN FOR: $srv" "$output"

        exitstatus=$?
        if [ ! $exitstatus = 0 ]; then
            log INFO "CANCELD CHOOSE VERSIONS" "$output"
            cleanup
            exit 1
        fi

    done
}

extract-choosed-versions(){
    local -r versions_path=${1:?}
    local file="${2:?}"

    for servers in $listServer; do

        if test -f "$servers"; then
            for server in servers; do
                versions=$(cat  $servers)

                selectionSrv="^$(echo $servers | sed -e 's/ /,|^/g'),"
                linesSrv=$(grep -E "$selectionSrv" "$versions_path")

                selectionVers="$(echo $versions | sed -e 's/ /,|/g'),"
                linesVers=$(echo "$linesSrv" | grep -E "$selectionVers")
                echo "$linesVers" >> $file

                rm $servers
            done
        fi
    done

}

dialog-choose-user(){
    local file="${1:?}"
    user=(
        "minecraft" "minecraft:minecraft (Standard)" on
        "nobody" "nobody:users (Unraid-Docker)" off
        "custom" "Custom" off)

    dialog --backtitle "Multicraft - JAR Config" --title "Choose Group and User" --radiolist "You can now select the group and the user who should own the conf files.\n\nPress SPACE to select and ENTER to validate your choices." 0 0 0 "${user[@]}" 2> "$file"

    exitstatus=$?
    if [ ! $exitstatus = 0 ]; then
        log INFO "CANCELD CHOOSE USER" "$output"
        cleanup
        exit 1
    fi

    choice=$(cat  $file)
    case "$choice" in

        minecraft)  echo -n "minecraft:minecraft" > "$file" ;;

        nobody)     echo -n "nobody:users" > "$file" ;;

        custom)     dialog-insert-user "user" ;;

        *)          log ERROR "WRONG INPUT AT CHOOSE USER" "$output" 
                    dialog-choose-user "$file" ;;
    esac
}

dialog-insert-user(){
    local file="${1:?}"

    dialog --backtitle "Multicraft - JAR Config" --title "Insert Group and User" --inputbox "You can now enter the group and the user who should own the conf files." 0 0 "group:user" 2> "$file"

    exitstatus=$?
    if [ ! $exitstatus = 0 ]; then
        log INFO "CANCELD INSERT USER" "$output"
        cleanup
        exit 1
    fi
}

dialog-choose-rights(){
    local file="${1:?}"
    rights=(
        "755" "r xr xr x" on
        "777" "rwxrwxrwx" off
        "custom" "Custom" off)

    dialog --backtitle "Multicraft - JAR Config" --title "Choose Rights" --radiolist "You can now select the rights to be set for the conf files.\n\nPress SPACE to select and ENTER to validate your choices." 0 0 0 "${rights[@]}" 2> "$file"

    exitstatus=$?
    if [ ! $exitstatus = 0 ]; then
        log INFO "CANCELD CHOOSE RIGHTS" "$output"
        cleanup
        exit 1
    fi

    choice=$(cat  $file)
    if [ "$choice" = "custom" ]; then
        dialog-insert-rights "rights"
    fi
}

dialog-insert-rights(){
    local file="${1:?}"

    dialog --backtitle "Multicraft - JAR Config" --title "Insert Rights" --inputbox "You can now enter the rights which should be set on the conf files.\nGroupUserOther" 0 0 "GUO" 2> "$file"

    exitstatus=$?
    if [ ! $exitstatus = 0 ]; then
        log INFO "CANCELD INSERT RIGHTS" "$output"
        cleanup
        exit 1
    fi

}

dialog-install-confs() {
    dialog --backtitle "Multicraft - JAR Config" --title "Let's go!" --msgbox "The choosed confs will now be installed." 13 60
}

install_choosed_versions(){
    local -r versions=${1:?}

    user=$(cat user)
    rights=$(cat rights)

    while IFS="," read -r server version java confVersion
    do
        if [ "$dry_run" = false ]; then
            if [[ "$server" == "custom" ]]; then
                wgetOut=$(wget -N -P $jar_path "$installer_url/$conf_path/$server/$version.jar.conf" 2>&1)
                chownOut=$(sudo chown $user "$jar_path/$version.jar.conf" 2>&1)
                chmodOut=$(sudo chmod $rights "$jar_path/$version.jar.conf" 2>&1)
                log INFO "WGET: --> $wgetOut" "$output"
                log INFO "CHOWN: --> $chownOut" "$output"
                log INFO "CHMOD: --> $chmodOut" "$output"
                sed -i -E "s|^configSource\s=\s(\S*)|configSource = $installer_url/$conf_path/$server/$version.jar.conf|" "$jar_path/$version.jar.conf"
            else
                wgetOut=$(wget -N -P $jar_path "$installer_url/$conf_path/$server/$server-$version.jar.conf" 2>&1)
                chownOut=$(sudo chown $user "$jar_path/$server-$version.jar.conf" 2>&1)
                chmodOut=$(sudo chmod $rights "$jar_path/$server-$version.jar.conf" 2>&1)
                log INFO "WGET: --> $wgetOut" "$output"
                log INFO "CHOWN: --> $chownOut" "$output"
                log INFO "CHMOD: --> $chmodOut" "$output"
                sed -i -E "s|^configSource\s=\s(\S*)|configSource = $installer_url/$conf_path/$server/$server-$version.jar.conf|" "$jar_path/$server-$version.jar.conf"
            fi
        else
            fake_install "$server-$version.jar.conf"
        fi
    done < "$versions"
    # to IGNORE HEADER LINE comment above line and uncomment lower line
    #done < <(tail -n +2 $versions)
}

fake-install() {
    echo "$1 fakely installed!" >> "$output"
}

cleanup(){
    log INFO "FINAL CLEANUP" "$output"
    rm choosedVersions.csv > /dev/null 2>&1
    rm user > /dev/null 2>&1
    rm rights > /dev/null 2>&1
}

dialog-installed() {
    dialog --backtitle "Multicraft - JAR Config" --title "Congratulation!" --msgbox "Everything is installed." 13 60
}

run "$@"
