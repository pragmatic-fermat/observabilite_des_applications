# Infrastructure des labs (Terraform)

Ce dossier decrit les machines des labs sur DigitalOcean : un couple `clt-N` /
`srv-N` par groupe, avec un terminal web HTTPS sur chacune.

## Ressources creees

Pour chaque numero N de 0 a `group_count - 1` :

- un droplet `clt-N` (machine cliente) et un droplet `srv-N` (machine serveur), initialises par `cloud-init-clt.yaml` et `cloud-init-srv.yaml` ;
- deux enregistrements DNS `clt-N` et `srv-N` dans la zone `domain_name` ;
- un tag commun (`tag_name`) et un projet DigitalOcean `training` qui regroupe les droplets.

## Terminal web

Chaque machine expose un terminal web sur `https://clt-N.<domaine>` et
`https://srv-N.<domaine>` :

- `ttyd` ecoute uniquement sur `127.0.0.1:7681` et ouvre des sessions directement en root ;
- Caddy publie ce port en HTTPS et obtient le certificat Let's Encrypt automatiquement, ce qui suppose que les enregistrements DNS pointent deja vers les droplets ;
- l'acces est protege par une basic auth, utilisateur `stagiaire`, mot de passe de la variable `webshell_password`.

Le binaire `ttyd` est epingle en version 1.7.7. Caddy est installe depuis son
depot officiel, sans epinglage de version.

## Utilisation avec Terraform Cloud

Creez un workspace relie a ce depot et indiquez `tf` comme repertoire de
travail Terraform. Definissez ensuite les variables dans le workspace :

| Variable | Type | Role |
|---|---|---|
| `do_token` | Terraform, sensible | Jeton d'API DigitalOcean |
| `root_password` | Terraform, sensible | Mot de passe du compte root, injecte dans les fichiers cloud-init |
| `webshell_password` | Terraform, sensible | Mot de passe du terminal web, communique aux participants |
| `domain_name` | Terraform | Zone DNS DigitalOcean qui recoit les enregistrements |
| `tag_name` | Terraform | Nom du tag applique aux droplets |
| `group_count` | Terraform | Nombre d'environnements |

Les autres variables (`region_name`, `droplet_size`, `droplet_image`,
`ssh_keys`) ont leur valeur dans `common.auto.tfvars`. Aucun secret ne doit etre
ecrit dans ce dossier.

## Controle en local

```bash
cd tf
terraform init -backend=false
terraform validate
```
