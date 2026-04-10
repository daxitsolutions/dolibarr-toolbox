#!/bin/sh

PATH_DOLIBARR_HTDOCS_ACTUEL="$1"
VERSION="$2"
EXCLUDE_CUSTOM="$3"
OUTPUT_FILE="$4"

ZIP_URL_BASE="https://github.com/Dolibarr/dolibarr/archive/refs/tags"
DL_CMD="curl"
UNZIP_CMD="unzip"

WORK_DIR="/tmp/dolibarr-diff"
TMP_DIR="$WORK_DIR"
LOG_FILE="$WORK_DIR/execution.log"
ZIP_FILE=""
BASE_EXTRACT=""
PATH_DOLIBARR_HTDOCS_BASE=""

EXCLUDE_CUSTOM_DIR="custom"

confirm() {
    printf "%s" "$1"
    read -r a
    case "$a" in
        Y|y) return 0 ;;
        *) return 1 ;;
    esac
}

log() {
    mkdir -p "$WORK_DIR" 2>/dev/null
    printf "%s\n" "$1" >> "$LOG_FILE"
}

is_truthy() {
    case "$1" in
        1|y|Y|yes|YES|true|TRUE|on|ON) return 0 ;;
        *) return 1 ;;
    esac
}

should_skip_relpath() {
    p="$1"
    if is_truthy "$EXCLUDE_CUSTOM"
    then
        case "$p" in
            "$EXCLUDE_CUSTOM_DIR"|"$EXCLUDE_CUSTOM_DIR"/*) return 0 ;;
        esac
    fi
    return 1
}

if [ -z "$PATH_DOLIBARR_HTDOCS_ACTUEL" ] || [ -z "$VERSION" ]
then
    printf "Usage: %s <PATH_DOLIBARR_HTDOCS_ACTUEL> <VERSION> [EXCLUDE_CUSTOM] [OUTPUT_FILE]\n" "$0"
    exit 1
fi

mkdir -p "$WORK_DIR" 2>/dev/null

if [ -z "$OUTPUT_FILE" ]
then
    OUTPUT_FILE="$WORK_DIR/diff_$(date +%Y%m%d_%H%M%S).txt"
fi

: > "$OUTPUT_FILE" 2>/dev/null || exit 1

ZIP_FILE="$TMP_DIR/dolibarr_$VERSION.zip"
BASE_EXTRACT="$TMP_DIR/dolibarr-$VERSION"
PATH_DOLIBARR_HTDOCS_BASE="$BASE_EXTRACT/htdocs"

log "Début exécution"
log "Actuel: $PATH_DOLIBARR_HTDOCS_ACTUEL"
log "Version: $VERSION"
log "Exclude custom: ${EXCLUDE_CUSTOM:-0}"
log "Work dir: $WORK_DIR"
log "ZIP cible: $ZIP_FILE"
log "Base extract: $BASE_EXTRACT"
log "Base htdocs: $PATH_DOLIBARR_HTDOCS_BASE"
log "Output: $OUTPUT_FILE"

if [ -f "$ZIP_FILE" ]
then
    if confirm "Le fichier ZIP existe déjà. Remplacer ? (Y/n) "
    then
        rm -f "$ZIP_FILE"
        log "Ancien ZIP supprimé"
    else
        log "ZIP existant conservé"
    fi
fi

if [ ! -f "$ZIP_FILE" ]
then
    if confirm "Télécharger Dolibarr $VERSION ? (Y/n) "
    then
        "$DL_CMD" -L "$ZIP_URL_BASE/$VERSION.zip" -o "$ZIP_FILE" || exit 1
        log "ZIP téléchargé"
    else
        log "Téléchargement annulé"
        exit 0
    fi
fi

if [ -d "$BASE_EXTRACT" ]
then
    if confirm "Le dossier décompressé existe déjà. Le supprimer ? (Y/n) "
    then
        rm -rf "$BASE_EXTRACT"
        log "Ancien dossier décompressé supprimé"
    else
        log "Ancien dossier conservé"
    fi
fi

if [ ! -d "$BASE_EXTRACT" ]
then
    "$UNZIP_CMD" -q "$ZIP_FILE" -d "$TMP_DIR" || exit 1
    log "ZIP décompressé"
fi

if [ ! -d "$PATH_DOLIBARR_HTDOCS_ACTUEL" ] || [ ! -d "$PATH_DOLIBARR_HTDOCS_BASE" ]
then
    log "Erreur: répertoires invalides"
    exit 1
fi

printf "Comparaison:\nActuel: %s\nBase: %s\nOutput: %s\n" "$PATH_DOLIBARR_HTDOCS_ACTUEL" "$PATH_DOLIBARR_HTDOCS_BASE" "$OUTPUT_FILE"
if is_truthy "$EXCLUDE_CUSTOM"
then
    printf "Exclusion: htdocs/%s\n" "$EXCLUDE_CUSTOM_DIR"
fi

if ! confirm "Confirmer et lancer le diff ? (Y/n) "
then
    log "Diff annulé"
    exit 0
fi

log "Comparaison lancée"

find "$PATH_DOLIBARR_HTDOCS_ACTUEL" -type f | while read -r f
do
    r="${f#$PATH_DOLIBARR_HTDOCS_ACTUEL/}"
    if should_skip_relpath "$r"
    then
        continue
    fi
    if [ -f "$PATH_DOLIBARR_HTDOCS_BASE/$r" ]
    then
        diff -u "$PATH_DOLIBARR_HTDOCS_ACTUEL/$r" "$PATH_DOLIBARR_HTDOCS_BASE/$r" >> "$OUTPUT_FILE"
    else
        printf "%s\n" "Absent dans base: $r" >> "$OUTPUT_FILE"
    fi
done

find "$PATH_DOLIBARR_HTDOCS_BASE" -type f | while read -r f
do
    r="${f#$PATH_DOLIBARR_HTDOCS_BASE/}"
    if should_skip_relpath "$r"
    then
        continue
    fi
    if [ ! -f "$PATH_DOLIBARR_HTDOCS_ACTUEL/$r" ]
    then
        printf "%s\n" "Absent dans actuel: $r" >> "$OUTPUT_FILE"
    fi
done

log "Diff terminé"

if confirm "Voulez-vous supprimer les sources décompressées : $BASE_EXTRACT ? (Y/n) "
then
    rm -rf "$BASE_EXTRACT"
    log "Sources décompressées supprimées: $BASE_EXTRACT"
else
    log "Sources décompressées conservées"
fi

log "Fin exécution"