#!/bin/bash
local TEMPLATE=/etc/kubernetes/controller-kubeconfig.yaml
echo "TEMPLATE: $TEMPLATE"
mkdir -p $(dirname $TEMPLATE)
cat <<EOF >$TEMPLATE
apiVersion: v1
kind: Config
clusters:
- name: local
  cluster:
    certificate-authority: /etc/kubernetes/ssl/ca.pem
users:
- name: controller
  user:
    client-certificate: /etc/kubernetes/ssl/controller.pem
    client-key: /etc/kubernetes/ssl/controller-key.pem
contexts:
- context:
    cluster: local
    user: controller
  name: controller-context
current-context: controller-context
EOF

local TEMPLATE=/etc/kubernetes/manifests/kube-controller-manager.yaml
echo "TEMPLATE: $TEMPLATE"
mkdir -p $(dirname $TEMPLATE)
cat <<EOF >$TEMPLATE
apiVersion: v1
kind: Pod
metadata:
  name: kube-controller-manager
  namespace: kube-system
spec:
  containers:
  - name: kube-controller-manager
    image: ${HYPERKUBE_IMAGE_REPO}/kube-controller-manager-amd64:$K8S_VER
    command:
    - /usr/local/bin/kube-controller-manager
    - --master=https://${ADVERTISE_IP}
    - --leader-elect=true
    - --service-account-private-key-file=/etc/kubernetes/ssl/controller-key.pem
    - --use-service-account-credentials
    - --root-ca-file=/etc/kubernetes/ssl/ca.pem
    - --node-monitor-period=2s
    - --node-monitor-grace-period=16s
    - --terminated-pod-gc-threshold=300
    - --pod-eviction-timeout=30s
    - --root-ca-file=/etc/kubernetes/ssl/ca.pem
    - --allocate-node-cidrs=true
    - --cluster-cidr=${POD_NETWORK}
    - --service-cluster-ip-range=${SERVICE_IP_RANGE}
    - --cluster-signing-cert-file=/etc/kubernetes/ssl/ca.pem
    - --cluster-signing-key-file=/etc/kubernetes/ssl/ca-key.pem
    - --horizontal-pod-autoscaler-use-rest-clients=true
    - --feature-gates=RotateKubeletClientCertificate=true,RotateKubeletServerCertificate=true
    - --kubeconfig=/etc/kubernetes/controller-kubeconfig.yaml
    - --terminated-pod-gc-threshold=100
    resources:
      requests:
        cpu: 200m
    livenessProbe:
      httpGet:
        host: 127.0.0.1
        path: /healthz
        port: 10252
      initialDelaySeconds: 15
      timeoutSeconds: 15
    volumeMounts:
    - mountPath: /etc/kubernetes/controller-kubeconfig.yaml
      name: "kubeconfig"
      readOnly: true
    - mountPath: /etc/kubernetes/ssl
      name: ssl-certs-kubernetes
      readOnly: true
    - mountPath: /etc/ssl/certs
      name: ssl-certs-host
      readOnly: true
  hostNetwork: true
  volumes:
  - name: "kubeconfig"
    hostPath:
      path: "/etc/kubernetes/controller-kubeconfig.yaml"
  - hostPath:
      path: /etc/kubernetes/ssl
    name: ssl-certs-kubernetes
  - hostPath:
      path: /usr/share/ca-certificates
    name: ssl-certs-host
EOF
