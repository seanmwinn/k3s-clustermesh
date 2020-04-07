# cilium-cluster-mesh

Creates two (or more) Kubernetes clusters based on k3s which can be used to
demonstrate, test and develop features related to Cilium cluster-mesh.

Set NUM_CLUSTERS equal to the number of clusters desired - default is 2.
Run `vagrant up` to bring up your clusters.

For each cluster, a config file is generated named `k3s-c${id}.yaml`. This
file is used as the KUBECONFIG file when using `kubectl` to access each cluster.

Install Cilium in each cluster:

```
for id in {1..$NUM_CLUSTERS}; do \
KUBECONFIG=k3s-c${id}.yaml helm install cilium cilium/cilium --namespace kube-system --set global.device=enp0s8\
--set global.etcd.enabled=true --set global.etcd.managed=true --set global.identityAllocationMode=kvstore \
--set global.cluster.name=cluster-${id} --set global.cluster.id=${id}
```

Apply the following to expose ETCD in each cluster:

```
for id in {1..$NUM_CLUSTERS}; do\
KUBECONFIG=k3s-c${id}.yaml kubectl apply -n kube-system -f https://raw.githubusercontent.com/cilium/cilium/v1.7/examples/kubernetes/clustermesh/cilium-etcd-external-service/cilium-etcd-external-nodeport.yaml;
done
```

Clone the cilium/clustermesh-tools repository. It contains scripts to extracts the secrets and generate a Kubernetes secret in form of a YAML file:

```
git clone https://github.com/cilium/clustermesh-tools.git
cd clustermesh-tools
```

For each cluster, extract the etcd secrets:

```
for id in {1..$NUM_CLUSTERS}; do \
KUBECONFIG=/path/to/k3s-c${id}.yaml ./extract-etcd-secrets.sh; \
done
```

Generate a cluster-mesh configuration:

`./generate-secret-yaml.sh > clustermesh.yaml'

Generate a DaemonSet patch for the cilium service configuring name resolution cross-cluster:

`./generate-name-mapping.sh > ds.patch`

The file contents are similar to this:
```yaml
spec:
  template:
    spec:
      hostAliases:
      - ip: "192.168.80.11"
        hostnames:
        - c1.mesh.cilium.io
      - ip: "192.168.80.12"
        hostnames:
        - c2.mesh.cilium.io
```

Apply the DaemonSet patch in each cluster:

```
for id in {1..$NUM_CLUSTERS}; do \
KUBECONFIG=/path/to/k3s-c${id}.yaml kubectl -n kube-system patch ds cilium -p "$(cat ds.patch)"; \
done
```

Finally apply the cluster-mesh configuration in each cluster:

```
for id in {1..$NUM_CLUSTERS}; do \
KUBECONFIG=/path/to/k3s-c${id}.yaml kubectl -n kube-system apply -f clustermesh.yaml; \
done
```

Restart the cilium-agent in each cluster:

```
for id in {1..$NUM_CLUSTERS}; do \
KUBECONFIG=/path/to/k3s-c${id}.yaml kubectl -n kube-system delete pods -l k8s-app=cilium;\
done
```

And restart the cilium-operator in each cluster:

```
for id in {1..$NUM_CLUSTERS}; do \
KUBECONFIG=/path/to/k3s-c${id}.yaml kubectl -n kube-system delete pods -l name=cilium-operator;\
done
```

Validate that Cilium cluster-mesh is functioning by checking the node list on any cilium pod:

`KUBECONFIG=k3s-c1.yaml kubectl -n kube-system exec cilium-j5kd0 cilium node list`

You should see output similar to the following where each node is prefixed with the cluster name:
```
Name            IPv4 Address    Endpoint CIDR   IPv6 Address   Endpoint CIDR
c1/master-c1   192.168.80.11   10.11.0.0/24
c2/master-c2   192.168.80.12   10.12.0.0/24
```

You can also verify the ClusterMesh status in the output of `cilium status`:

```
kubectl exec -n kube-system cilium-dlkb5 cilium status
KVStore:                Ok   etcd: 1/1 connected, lease-ID=56bd7155ae54b387, lock lease-ID=56bd7155ae54b389, has-quorum=true: https://cilium-etcd-client.kube-system.svc:2379 - 3.3.12
Kubernetes:             Ok   1.17 (v1.17.4+k3s1) [linux/amd64]
Kubernetes APIs:        ["CustomResourceDefinition", "cilium/v2::CiliumClusterwideNetworkPolicy", "cilium/v2::CiliumNetworkPolicy", "core/v1::Endpoint", "core/v1::Namespace", "core/v1::Pods", "core/v1::Service", "networking.k8s.io/v1::NetworkPolicy"]
KubeProxyReplacement:   Probe   [NodePort (SNAT, 30000-32767), ExternalIPs, HostReachableServices (TCP, UDP)]
Cilium:                 Ok      OK
NodeMonitor:            Disabled
Cilium health daemon:   Ok
IPAM:                   IPv4: 13/255 allocated from 10.11.0.0/24,
ClusterMesh:            1/1 clusters ready, 1 global-services
Controller Status:      72/72 healthy
Proxy Status:           OK, ip 10.11.0.242, 0 redirects active on ports 10000-20000
Cluster health:   2/2 reachable   (2020-04-07T22:41:10Z)
```

Apply the application demo files in each cluster and ensure that the x-wing services in each cluster are making use of global services.

```
for id in {1..$NUM_CLUSTERS}; do \
KUBECONFIG=k3s-c${id}.yaml kubectl apply -f cluster$id.yaml; \
done
```

In the log output of the x-wing services we should see data returned from both clusters:

`KUBECONFIG=k3s-c1.yaml kubectl logs -l name=x-wing`

```
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
```

When you are done, cleanup the environment `vagrant destroy -f`
