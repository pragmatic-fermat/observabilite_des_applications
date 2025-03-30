# Récupère la liste des IDs et des noms de cluster
clusters=$(doctl kubernetes cluster list --format ID,Name --no-header)

# Pour chaque cluster, installe metrics-server et ingress-nginx
echo "$clusters" | while read -r id name; do
  echo "👉 Traitement du cluster: $name (ID: $id)"
  
  # Récupérer les credentials pour kubectl
  doctl kubernetes cluster kubeconfig save "$id"
  
  # Installer metrics-server
  echo "📦 Installation de metrics-server,ingress-nginx sur $name..."
  doctl kubernetes 1-click install "$id" --1-clicks metrics-server,ingress-nginx

  echo "✅ Terminé pour $name"
  echo "---------------------------------------------"
done
