https://istio.io/latest/docs/setup/install/helm/

helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

kubectl create namespace istio-system

helm install istio-base istio/base -n istio-system --set defaultRevision=default

helm install istiod istio/istiod -n istio-system --wait
kubectl create namespace istio-ingress

helm upgrade --install istio-ingress istio/gateway -n istio-ingress --values istio_gateway_values_prod.yaml

kubectl create -n istio-ingress secret tls tls-wildcard   --key=/home/geoff/ca/wildcard.lan.asio.key   --cert=/home/geoff/ca/wildcard.lan.asio.pem
kubectl apply -f gateway.yaml
