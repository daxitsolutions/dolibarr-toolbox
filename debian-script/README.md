# compare_dolibarr.sh

Script shell pour comparer un Dolibarr local avec une version officielle (tag GitHub).

## Prérequis

- `curl`
- `unzip`
- `diff`

## Usage

### Nouveau format recommandé

```sh
./compare_dolibarr.sh -v <VERSION> [options] <PATH_DOLIBARR_ACTUEL>
```

Exemples:

```sh
# Compare une instance locale complète (racine Dolibarr) avec la même structure du tag
./compare_dolibarr.sh -v 20.0.4 /var/www/dolibarr

# Compare uniquement htdocs (même si on passe la racine)
./compare_dolibarr.sh -v 20.0.4 --htdocs-only /var/www/dolibarr

# Compare htdocs et exclut custom
./compare_dolibarr.sh -v 20.0.4 --htdocs-only --exclude-custom /var/www/dolibarr

# Écrit le résultat dans un fichier précis
./compare_dolibarr.sh -v 20.0.4 -o /tmp/diff_doli.txt /var/www/dolibarr
```

### Format historique (compatibilité)

```sh
./compare_dolibarr.sh <PATH_DOLIBARR_ACTUEL> <VERSION> [EXCLUDE_CUSTOM] [OUTPUT_FILE]
```

## Options

- `-v <VERSION>`: version Dolibarr cible (ex: `20.0.4`)
- `-o <OUTPUT_FILE>`: fichier de sortie du diff
- `-c`, `--exclude-custom`: exclut `custom` du diff
- `--htdocs-only`: force la comparaison uniquement sur `htdocs`
- `-h`, `--help`: affiche l’aide
- `--script-version`: affiche la version du script

## Comportement de comparaison

- Si `--htdocs-only` est activé:
  - le script compare uniquement `htdocs` côté local et côté base.
- Sans `--htdocs-only`:
  - si le chemin local contient un sous-dossier `htdocs`, le script compare la racine complète;
  - sinon il compare le dossier local fourni avec `htdocs` de la version téléchargée.

## Fichiers temporaires

- Dossier de travail: `/tmp/dolibarr-diff`
- Logs: `/tmp/dolibarr-diff/execution.log`
- ZIP et extraction sont stockés temporairement dans ce dossier.
