
kubectl delete --namespace hcf -f test-kube/nats.yml
kubectl delete --namespace hcf -f test-kube/consul.yml
kubectl delete --namespace hcf -f test-kube/mysql.yml
kubectl delete --namespace hcf -f test-kube/mysql-proxy.yml
kubectl delete --namespace hcf -f test-kube/etcd.yml
kubectl delete --namespace hcf -f test-kube/diego-database.yml
kubectl delete --namespace hcf -f test-kube/router.yml
kubectl delete --namespace hcf -f test-kube/tcp-router.yml
kubectl delete --namespace hcf -f test-kube/routing-api.yml
kubectl delete --namespace hcf -f test-kube/uaa.yml
kubectl delete --namespace hcf -f test-kube/api.yml
kubectl delete --namespace hcf -f test-kube/api-worker.yml
kubectl delete --namespace hcf -f test-kube/blobstore.yml
kubectl delete --namespace hcf -f test-kube/clock-global.yml
kubectl delete --namespace hcf -f test-kube/doppler.yml
kubectl delete --namespace hcf -f test-kube/etcd.yml
kubectl delete --namespace hcf -f test-kube/loggregator.yml
kubectl delete --namespace hcf -f test-kube/diego-brain.yml
kubectl delete --namespace hcf -f test-kube/diego-cc-bridge.yml
kubectl delete --namespace hcf -f test-kube/diego-route-emitter.yml
kubectl delete --namespace hcf -f test-kube/diego-access.yml
kubectl delete --namespace hcf -f test-kube/diego-cell.yml

k delete pv --all
k delete pvc --namespace hcf --all
