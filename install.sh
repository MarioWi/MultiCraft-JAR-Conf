#!/usr/bin/env bash

# e - script stops on error
# u - error if undefined variable
# o pipefail - script fails if command piped fails
set -euo pipefail

# YOU NEED TO MODIFY YOUR INSTALL URL
url-installer() {
    echo "https://raw.githubusercontent.com/MarioWi/MultiCraft-JAR-Conf/master"
}


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
    #log INFO "DOWNLOAD VERSIONS CSV" "$output"
    #versions_path="$(download-versions-csv "$versions_url")"
    #log INFO "VERSIONS CSV DOWNLOADED AT: $versions_path" "$output"
    check-file "update.sh"

    dialog-choose-server srv
    choicesSrv=$(cat srv) && rm srv
    log INFO "server CHOOSEN: $choicesSrv" "$output"
    lines="$(extract-choosed-servers "$choices" "$versions_path")"

}

log() {
    local -r level=${1:?}
    local -r message=${2:?}
    local -r output=${3:?}
    local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    echo -e "${timestamp} [${level}] ${message}" >>"$output"
}

check-file(){
    if [ ! -f ${1:?} ] then
        download-file "$1"
    fi
}

download-file(){
    curl "$url_installer/$1" > "./$1"
}

install-dialog() {
    sudo apt-get update && sudo apt-get upgrade
    sudo apt-get install dialog -y
}

dialog-welcome() {
    dialog --title "Welcome!" --msgbox "Welcome to MarioWi's Multicraft JAR-Conf downloader.\n" 10 60
}

dialog-chose-server(){
    local file=${1:?}

    server=(
        "vanilla" "Vanilla" on 
        "spigot" "Spigot" on
        "paperspigot" "PaperSpigot" on
        "custom" "Custom" off)

    dialog --checklist "You can now choose the groups of Server/APIs you want to install, according to your own CSV file.\n\n Press SPACE to select and ENTER to validate your choices." 0 0 0 "${server[@]}" 2> "$file"
}

