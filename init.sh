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

## install Helm
if ! helm version ; then
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  chmod 700 get_helm.sh
  ./get_helm.sh
  sudo chmod a+x /usr/local/bin/helm
  helm version
  rm -f ./get_helm.sh
fi

if ! k9s version ; then
	echo "Installation de k9s"
	curl -sS https://webinstall.dev/k9s | bash
	k9s version
else
	echo "k9s deja installe"
fi


echo "----"
echo "Votre groupe : ${GRP}"