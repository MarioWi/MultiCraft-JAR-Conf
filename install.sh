#!/usr/bin/env bash

# e - script stops on error
# u - error if undefined variable
# o pipefail - script fails if command piped fails
#set -euo pipefail

# YOU NEED TO MODIFY YOUR INSTALL URL
url-installer() {
    echo "https://raw.githubusercontent.com/MarioWi/MultiCraft-JAR-Conf/master"
}
versions_path="$(url-installer)/versions.csv"
path_to_confs="minecraft"
listServer="vanilla spigot paperspigot custom"

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

    install-dialog

    dialog-welcome

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
    install_choosed_versions "choosedVersions.csv"

    cleanup

}

log() {
    local -r level=${1:?}
    local -r message=${2:?}
    local -r output=${3:?}
    local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    echo -e "${timestamp} [${level}] ${message}" >>"$output"
}

check-file(){
    log INFO "CHECK IF $1 ALREADY EXISTS" "$output"
    if [ ! -f ${1:?} ]
    then
        download-file "$1"
    fi
}

download-file(){
    curl "$(url-installer)/$1" > "./$1"
    log INFO "$1 DOWNLOADED AT: $(url-installer)/$1" "$output"
}

install-dialog() {

    command -v "dialog" >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        sudo apt-get update -y && sudo apt-get upgrade -y
        sudo apt-get install dialog -y
    fi
}

dialog-welcome() {
    dialog --title "Welcome!" --msgbox "Welcome to the Multicraft JAR-Conf downloader.\n" 10 60
}

dialog-choose-server(){
    local file=${1:?}

    server=(
        "vanilla" "Vanilla" on
        "spigot" "Spigot" on
        "paperspigot" "PaperSpigot" on
        "custom" "Custom" off)

    dialog --checklist "You can now choose the groups of Server/APIs you want to install, according to your own CSV file.\n\nPress SPACE to select and ENTER to validate your choices." 0 0 0 "${server[@]}" 2> "$file"

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
            if [[ "$srv" == "custom" ]]; then
                array[ $i + 1]=$version.jar.conf
            else
                array[ $i + 1]=$srv-$version.jar.conf
            fi
            array[ ($i + 2) ]=$srv-$version
            (( i=($i+3) ))
        done

        dialog --title "$srv" --checklist "You can now choose the groups of Versions you want to install for $srv, according to your own CSV file.\n\nPress SPACE to select and ENTER to validate your choices." 0 0 0 "${array[@]}" 2> "$srv"
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

    dialog --radiolist "You can now select the group and the user who should own the conf files.\n\nPress SPACE to select and ENTER to validate your choices." 0 0 0 "${user[@]}" 2> "$file"

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

    dialog --inputbox "You can now enter the group and the user who should own the conf files." 0 0 "group:user" 2> "$file"

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

    dialog --radiolist "You can now select the rights to be set for the conf files.\n\nPress SPACE to select and ENTER to validate your choices." 0 0 0 "${rights[@]}" 2> "$file"

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

    dialog --inputbox "You can now enter the rights which should be set on the conf files.\nGroupUserOther" 0 0 "GUO" 2> "$file"

    exitstatus=$?
    if [ ! $exitstatus = 0 ]; then
        log INFO "CANCELD INSERT RIGHTS" "$output"
        cleanup
        exit 1
    fi

}

install_choosed_versions(){
    local -r versions=${1:?}

    user=$(cat user)
    rights=$(cat rights)

    while IFS="," read -r server version java confVersion
    do
        if [ "$dry_run" = false ]; then
            wgetOut=$(wget -N -P ./jar "$(url-installer)/$path_to_confs/$server/$server-$version.jar.conf" 2>&1)
            chownOut=$(sudo chown $user "./jar/$server-$version.jar.conf" 2>&1)
            chmodOut=$(sudo chmod $rights "./jar/$server-$version.jar.conf" 2>&1)
            log INFO "WGET: --> $wgetOut" "$output"
            log INFO "CHOWN: --> $chownOut" "$output"
            log INFO "CHMOD: --> $chmodOut" "$output"
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
    rm choosedVersions.csv && rm user && rm rights
}

run "$@"
