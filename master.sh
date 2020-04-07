sudo mount bpffs -t bpf /sys/fs/bpf


export MASTER_IP=$(ip a |grep global | grep -v '10.0.2.15' | awk '{print $2}' | cut -f1 -d '/')
export CLUSTERIP=$(echo ${MASTER_IP} | cut -f4 -d '.')
export CLUSTERID=$(hostname | cut -f2 -d '-')

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--flannel-backend=none \
--no-flannel --node-ip=${MASTER_IP} --node-external-ip=${MASTER_IP} \
--bind-address=${MASTER_IP} --no-deploy servicelb --no-deploy traefik \
--kube-controller-manager-arg cluster-cidr=10.${CLUSTERIP}.0.0/16" sh -

sudo cp /etc/rancher/k3s/k3s.yaml /vagrant/k3s-${CLUSTERID}.yaml
sudo sed -i -e "s/127.0.0.1/${MASTER_IP}/g" /vagrant/k3s-${CLUSTERID}.yaml
