#!/bin/sh

###
if [ -z "$2" ]; then 
   echo "Syntax Error: $0 <numero de cluster> <entropy>"
   exit 0
fi

GRP=$1

ENTROPY=$2
URL="https://kconfig.fra1.digitaloceanspaces.com/k8-do-grp${GRP}-${ENTROPY}.kubeconfig.yaml"
echo "Downloading $URL ..."

[ ! -d ~/.kube ] && mkdir ~/.kube
wget -nv $URL -O ~/.kube/config

echo "Securing access to kubeconfig"
chmod o-r ~/.kube/config
chmod g-r ~/.kube/config

kubectl cluster-info

if [ $? -ne 0 ]; then 
  echo "mauvais kubeconfig!"
  exit -2;
fi

echo "----"
echo "Votre groupe : ${GRP}"