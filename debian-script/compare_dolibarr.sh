#!/bin/sh

SCRIPT_VERSION="1.1.0"

PATH_DOLIBARR_ACTUEL=""
VERSION=""
EXCLUDE_CUSTOM="0"
OUTPUT_FILE=""
ONLY_HTDOCS="0"

ZIP_URL_BASE="https://github.com/Dolibarr/dolibarr/archive/refs/tags"
DL_CMD="curl"
UNZIP_CMD="unzip"

WORK_DIR="/tmp/dolibarr-diff"
TMP_DIR="$WORK_DIR"
LOG_FILE="$WORK_DIR/execution.log"
ZIP_FILE=""
BASE_EXTRACT_ROOT=""
CURRENT_COMPARE_DIR=""
BASE_COMPARE_DIR=""

EXCLUDE_CUSTOM_DIR="custom"

usage() {
    cat <<EOF
Usage:
  $0 -v <VERSION> [options] <PATH_DOLIBARR_ACTUEL>
  $0 <PATH_DOLIBARR_ACTUEL> <VERSION> [EXCLUDE_CUSTOM] [OUTPUT_FILE]

Description:
  Compare un Dolibarr local avec une version officielle téléchargée depuis GitHub.

Options:
  -v <VERSION>         Version Dolibarr cible (ex: 20.0.4)
  -o <OUTPUT_FILE>     Chemin du fichier de sortie diff
  -c, --exclude-custom Exclut htdocs/custom du diff
  --htdocs-only        Compare uniquement le sous-répertoire htdocs
  --script-version     Affiche la version du script
  -h, --help           Affiche cette aide
EOF
}

die() {
    printf "Erreur: %s\n" "$1" >&2
    exit 1
}

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
            "$EXCLUDE_CUSTOM_DIR"|"$EXCLUDE_CUSTOM_DIR"/*|htdocs/"$EXCLUDE_CUSTOM_DIR"|htdocs/"$EXCLUDE_CUSTOM_DIR"/*) return 0 ;;
        esac
    fi
    return 1
}

while [ $# -gt 0 ]
do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --script-version)
            printf "%s\n" "$SCRIPT_VERSION"
            exit 0
            ;;
        -v)
            shift
            [ $# -gt 0 ] || die "L'option -v attend une version"
            VERSION="$1"
            ;;
        -o|--output)
            opt_name="$1"
            shift
            [ $# -gt 0 ] || die "L'option $opt_name attend un fichier"
            OUTPUT_FILE="$1"
            ;;
        -c|--exclude-custom)
            EXCLUDE_CUSTOM="1"
            ;;
        --htdocs-only)
            ONLY_HTDOCS="1"
            ;;
        --)
            shift
            break
            ;;
        -*)
            die "Option inconnue: $1 (utilise -h pour l'aide)"
            ;;
        *)
            break
            ;;
    esac
    shift
done

if [ -n "$VERSION" ]
then
    [ $# -ge 1 ] || die "Chemin Dolibarr manquant"
    PATH_DOLIBARR_ACTUEL="$1"
    if [ -z "$OUTPUT_FILE" ] && [ $# -ge 2 ]
    then
        OUTPUT_FILE="$2"
    fi
else
    # Mode historique: <PATH> <VERSION> [EXCLUDE_CUSTOM] [OUTPUT_FILE]
    [ $# -ge 2 ] || { usage; exit 1; }
    PATH_DOLIBARR_ACTUEL="$1"
    VERSION="$2"
    if [ $# -ge 3 ] && [ "$EXCLUDE_CUSTOM" = "0" ]
    then
        EXCLUDE_CUSTOM="$3"
    fi
    if [ $# -ge 4 ] && [ -z "$OUTPUT_FILE" ]
    then
        OUTPUT_FILE="$4"
    fi
fi

[ -d "$PATH_DOLIBARR_ACTUEL" ] || die "Chemin Dolibarr introuvable: $PATH_DOLIBARR_ACTUEL"

mkdir -p "$WORK_DIR" 2>/dev/null

if [ -z "$OUTPUT_FILE" ]
then
    OUTPUT_FILE="$WORK_DIR/diff_$(date +%Y%m%d_%H%M%S).txt"
fi

: > "$OUTPUT_FILE" 2>/dev/null || die "Impossible d'écrire dans $OUTPUT_FILE"

ZIP_FILE="$TMP_DIR/dolibarr_$VERSION.zip"
BASE_EXTRACT_ROOT="$TMP_DIR/dolibarr-$VERSION"

if is_truthy "$ONLY_HTDOCS"
then
    if [ -d "$PATH_DOLIBARR_ACTUEL/htdocs" ]
    then
        CURRENT_COMPARE_DIR="$PATH_DOLIBARR_ACTUEL/htdocs"
    else
        CURRENT_COMPARE_DIR="$PATH_DOLIBARR_ACTUEL"
    fi
    BASE_COMPARE_DIR="$BASE_EXTRACT_ROOT/htdocs"
else
    CURRENT_COMPARE_DIR="$PATH_DOLIBARR_ACTUEL"
    if [ -d "$PATH_DOLIBARR_ACTUEL/htdocs" ]
    then
        BASE_COMPARE_DIR="$BASE_EXTRACT_ROOT"
    else
        BASE_COMPARE_DIR="$BASE_EXTRACT_ROOT/htdocs"
    fi
fi

log "Début exécution"
log "Actuel: $PATH_DOLIBARR_ACTUEL"
log "Version: $VERSION"
log "Exclude custom: ${EXCLUDE_CUSTOM:-0}"
log "Only htdocs: ${ONLY_HTDOCS:-0}"
log "Work dir: $WORK_DIR"
log "ZIP cible: $ZIP_FILE"
log "Base extract root: $BASE_EXTRACT_ROOT"
log "Comparaison actuel: $CURRENT_COMPARE_DIR"
log "Comparaison base: $BASE_COMPARE_DIR"
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
        "$DL_CMD" -L "$ZIP_URL_BASE/$VERSION.zip" -o "$ZIP_FILE" || die "Échec du téléchargement"
        log "ZIP téléchargé"
    else
        log "Téléchargement annulé"
        exit 0
    fi
fi

if [ -d "$BASE_EXTRACT_ROOT" ]
then
    if confirm "Le dossier décompressé existe déjà. Le supprimer ? (Y/n) "
    then
        rm -rf "$BASE_EXTRACT_ROOT"
        log "Ancien dossier décompressé supprimé"
    else
        log "Ancien dossier conservé"
    fi
fi

if [ ! -d "$BASE_EXTRACT_ROOT" ]
then
    "$UNZIP_CMD" -q "$ZIP_FILE" -d "$TMP_DIR" || die "Échec de la décompression"
    log "ZIP décompressé"
fi

if [ ! -d "$CURRENT_COMPARE_DIR" ] || [ ! -d "$BASE_COMPARE_DIR" ]
then
    log "Erreur: répertoires invalides"
    die "Répertoires invalides. Actuel=$CURRENT_COMPARE_DIR, Base=$BASE_COMPARE_DIR"
fi

printf "Comparaison:\nActuel: %s\nBase: %s\nOutput: %s\n" "$CURRENT_COMPARE_DIR" "$BASE_COMPARE_DIR" "$OUTPUT_FILE"
if is_truthy "$ONLY_HTDOCS"
then
    printf "Mode: htdocs only\n"
fi
if is_truthy "$EXCLUDE_CUSTOM"
then
    printf "Exclusion: %s\n" "$EXCLUDE_CUSTOM_DIR"
fi

if ! confirm "Confirmer et lancer le diff ? (Y/n) "
then
    log "Diff annulé"
    exit 0
fi

log "Comparaison lancée"

find "$CURRENT_COMPARE_DIR" -type f | while read -r f
do
    r="${f#$CURRENT_COMPARE_DIR/}"
    if should_skip_relpath "$r"
    then
        continue
    fi
    if [ -f "$BASE_COMPARE_DIR/$r" ]
    then
        diff -u "$CURRENT_COMPARE_DIR/$r" "$BASE_COMPARE_DIR/$r" >> "$OUTPUT_FILE"
    else
        printf "%s\n" "Absent dans base: $r" >> "$OUTPUT_FILE"
    fi
done

find "$BASE_COMPARE_DIR" -type f | while read -r f
do
    r="${f#$BASE_COMPARE_DIR/}"
    if should_skip_relpath "$r"
    then
        continue
    fi
    if [ ! -f "$CURRENT_COMPARE_DIR/$r" ]
    then
        printf "%s\n" "Absent dans actuel: $r" >> "$OUTPUT_FILE"
    fi
done

log "Diff terminé"

if confirm "Voulez-vous supprimer les sources décompressées : $BASE_EXTRACT_ROOT ? (Y/n) "
then
    rm -rf "$BASE_EXTRACT_ROOT"
    log "Sources décompressées supprimées: $BASE_EXTRACT_ROOT"
else
    log "Sources décompressées conservées"
fi

log "Fin exécution"
