#!/usr/bin/env bash

# e - script stops on error
# u - error if undefined variable
# o pipefail - script fails if command piped fails
#set -euo pipefail

# YOU NEED TO MODIFY YOUR INSTALL URL
url-installer() {
    echo "https://raw.githubusercontent.com/MarioWi/MultiCraft-JAR-Conf/master"
}

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
    versions_path="$(url-installer)/versions.csv"
    #log INFO "DOWNLOAD VERSIONS CSV" "$output"
    #versions_path="$(download-versions-csv "$versions_url")"
    #log INFO "VERSIONS CSV DOWNLOADED AT: $versions_path" "$output"
    check-file "update.sh"

    dialog-choose-server srv
    choicesSrv=$(cat srv) && rm srv

    #printf '%s\n' "$choicesSrv"
    #read -rsp "Press any key to continue..." -n1 key

    log INFO "server CHOOSEN: $choicesSrv" "$output"
    servers="$(extract-choosed-servers "$choicesSrv" "versions.csv")"
    #log INFO "GENERATED LINES: $lines" "$output"

    #printf '%s\n' "$servers"
    #read -rsp "Press any key to continue..." -n1 key

    dialog-choose-versions "vers" "$choicesSrv" "$servers"

    #printf '%s\n' "$vers"
    #read -rsp "Press any key to continue..." -n1 key

    #choicesVersions=$(cat vers) && rm vers
    #log INFO "server CHOOSEN: $choicesSrv" "$output"

    #printf '%s\n' "$choicesVersions"
    #read -rsp "Press any key to continue..." -n1 key

    extract-choosed-versions "versions.csv" "choosedVersions.csv"

    dialog-choose-user "user"

    dialog-choose-rights "rights"

    install_choosed_versions "choosedVersions.csv"

    rm choosedVersions.csv && rm user && rm rights

}

log() {
    local -r level=${1:?}
    local -r message=${2:?}
    local -r output=${3:?}
    local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    echo -e "${timestamp} [${level}] ${message}" >>"$output"
}

check-file(){
    if [ ! -f ${1:?} ]
    then
        download-file "$1"
    fi
}

download-file(){
    curl "$(url-installer)/$1" > "./$1"
}

install-dialog() {

    command -v "dialog" >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        sudo apt-get update -y && sudo apt-get upgrade -y
        sudo apt-get install dialog -y
    fi
}

dialog-welcome() {
    dialog --title "Welcome!" --msgbox "Welcome to MarioWi's Multicraft JAR-Conf downloader.\n" 10 60
}

dialog-choose-server(){
    local file=${1:?}

    server=(
        "vanilla" "Vanilla" on
        "spigot" "Spigot" on
        "paperspigot" "PaperSpigot" on
        "custom" "Custom" off)

    dialog --checklist "You can now choose the groups of Server/APIs you want to install, according to your own CSV file.\n\nPress SPACE to select and ENTER to validate your choices." 0 0 0 "${server[@]}" 2> "$file"

    if [ ! $exitstatus = 0 ]; then
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
        j=1 #Option menu value generator

        #printf '%s\n' "$srv"
        #read -rsp "Press any key to continue..." -n1 key

        selection="^$(echo $srv | sed -e 's/ /,|^/g'),"
        lines=$(echo "$servers" | grep -w "$srv")
        for k in $lines; do
            version=$(echo $k | awk -F ',' '{print $2;}')
            array[ $i ]=$version
        	(( j++ ))
            if [[ "$srv" == "custom" ]]; then
                array[ $i + 1]=$version.jar.conf
            else
                array[ $i + 1]=$srv-$version.jar.conf
            fi
            array[ ($i + 2) ]=$srv-$version
            (( i=($i+3) ))
        done

        #printf '%s\n' "${array[@]}"
        ##printf '%s\n' "$lines"
        ##printf '%s\n' "$RADIOLIST"
        #read -rsp "Press any key to continue..." -n1 key

        #dialog --title "$srv" --checklist "You can now choose the groups of Versions you want to install for $srv, according to your own CSV file.\n\nPress SPACE to select and ENTER to validate your choices." 0 0 0 "${array[@]}" 2>> "$file"
        dialog --title "$srv" --checklist "You can now choose the groups of Versions you want to install for $srv, according to your own CSV file.\n\nPress SPACE to select and ENTER to validate your choices." 0 0 0 "${array[@]}" 2> "$srv"

    if [ ! $exitstatus = 0 ]; then
            exit 1
        fi

    done
}

extract-choosed-versions(){
    local -r versions_path=${1:?}
    local file="${2:?}"

    for servers in $listServer; do
        #printf '%s\n' "Server: $servers"
        #read -rsp "Press any key to continue..." -n1 key

        if test -f "$servers"; then
            for server in servers; do
                versions=$(cat  $servers)

                #printf '%s\n' "Versions: $versions"
                #read -rsp "Press any key to continue..." -n1 key

                selectionSrv="^$(echo $servers | sed -e 's/ /,|^/g'),"
                linesSrv=$(grep -E "$selectionSrv" "$versions_path")

                #printf '%s\n' "SelectionSrv: $selectionSrv"
                #printf '%s\n' "LinesSrv: $linesSrv"
                #read -rsp "Press any key to continue..." -n1 key

                selectionVers="$(echo $versions | sed -e 's/ /,|/g'),"
                linesVers=$(echo "$linesSrv" | grep -E "$selectionVers")
                echo "$linesVers" >> $file

                #printf '%s\n' "SelectionVers: $selectionVers"
                #printf '%s\n' "LinesVers: $linesVers"
                #read -rsp "Press any key to continue..." -n1 key
                rm $servers
            done
        fi
    done

}

dialog-choose-user(){
    local file="${1:?}"
    #"user"
    user=(
        "minecraft" "minecraft:minecraft (Standard)" on
        "nobody" "nobody:users (Unraid-Docker)" off
        "custom" "Custom" off)

    dialog --radiolist "You can now select the group and the user who should own the conf files." 0 0 0 "${user[@]}" 2> "$file"

    if [ ! $exitstatus = 0 ]; then
        exit 1
    fi

    choice=$(cat  $file)
    #if [ "$choice" = "custom" ]; then
    #    dialog-insert-user "user"
    #fi
    case "$choice" in

        minecraft) echo -n "minecraft:minecraft" > "$file" ;;

        nobody) echo -n "nobody:users" > "$file" ;;

        custom) dialog-insert-user "user" ;;

        *) echo "Sorry, invalid input" ;;
    esac
    #printf '%s\n' "LinesVers: $linesVers"
    #read -rsp "Press any key to continue..." -n1 key

}

dialog-insert-user(){
    local file="${1:?}"

    dialog --inputbox "You can now enter the group and the user who should own the conf files." 0 0 "group:user" 2> "$file"

    if [ ! $exitstatus = 0 ]; then
        exit 1
    fi
}

dialog-choose-rights(){
    local file="${1:?}"
    #"rights"
    rights=(
        "755" "r xr xr x" on
        "777" "rwxrwxrwx" off
        "custom" "Custom" off)

    dialog --radiolist "You can now select the rights to be set for the conf files." 0 0 0 "${rights[@]}" 2> "$file"

    if [ ! $exitstatus = 0 ]; then
        exit 1
    fi

    choice=$(cat  $file)
    if [ "$choice" = "custom" ]; then
        dialog-insert-rights "rights"
    fi

    #printf '%s\n' "LinesVers: $linesVers"
    #read -rsp "Press any key to continue..." -n1 key

}

dialog-insert-rights(){
    local file="${1:?}"

    dialog --inputbox "You can now enter the rights which should be set on the conf files.\nGroupUserOther" 0 0 "GUO" 2> "$file"

    if [ ! $exitstatus = 0 ]; then
        exit 1
    fi

}

install_choosed_versions(){
    local -r versions=${1:?}

    user=$(cat user)
    rights=$(cat rights)
 
    while IFS="," read -r server version java confVersion
    do
        wget -N -P ./jar "$(url-installer)/$path_to_confs/$server/$server-$version.jar.conf"
        sudo chown $user "./jar/$server-$version.jar.conf"
        sudo chmod $rights "./jar/$server-$version.jar.conf"
        #chown minecraft:minecraft ./jar/spigot-1.16.2.jar.conf
        #chmod 755 ./jar/spigot-1.16.2.jar.conf
    done < "$versions"
    # ignore header line
    #done < <(tail -n +2 $versions)

    printf '%s\n' "Install?..."
    read -rsp "Press any key to continue..." -n1 key
}

run "$@"
