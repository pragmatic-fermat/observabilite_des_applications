# Infrastructure des labs (Terraform)

Ce dossier decrit les machines des labs sur DigitalOcean : un couple `clt-N` /
`srv-N` par groupe, avec un terminal web HTTPS sur chacune.

## Ressources creees

Pour chaque numero N de 0 a `group_count - 1` :

- un droplet `clt-N` (machine cliente) et un droplet `srv-N` (machine serveur), initialises par `cloud-init-clt.yaml` et `cloud-init-srv.yaml` ;
- un VPC `vpc-N` (plage `10.20.N.0/24`, decoupee depuis `vpc_base_range`) dans lequel sont places les deux droplets du groupe : les machines d'un meme groupe se voient sur le reseau prive, les groupes restent cloisonnes entre eux ;
- deux enregistrements DNS `clt-N` et `srv-N` dans la zone `domain_name`, avec un TTL de 60 secondes adapte aux machines ephemeres ;
- un tag commun (`tag_name`) et un projet DigitalOcean `training` qui regroupe les droplets (les VPC ne sont pas assignables a un projet, ils restent en dehors).

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
`ssh_keys`, `vpc_base_range`) ont leur valeur dans `common.auto.tfvars`. Aucun
secret ne doit etre ecrit dans ce dossier.

## Controle en local

```bash
cd tf
terraform init -backend=false
terraform validate
```
