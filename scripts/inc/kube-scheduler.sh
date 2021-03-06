#!/bin/bash

local TEMPLATE=/etc/kubernetes/scheduler-kubeconfig.yaml
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
- name: kubelet
  user:
    client-certificate: /etc/kubernetes/ssl/scheduler.pem
    client-key: /etc/kubernetes/ssl/scheduler-key.pem
contexts:
- context:
    cluster: local
    user: kubelet
  name: kubelet-context
current-context: kubelet-context
EOF

local TEMPLATE=/etc/kubernetes/manifests/kube-scheduler.yaml
echo "TEMPLATE: $TEMPLATE"
mkdir -p $(dirname $TEMPLATE)
cat <<EOF >$TEMPLATE
apiVersion: v1
kind: Pod
metadata:
  name: kube-scheduler
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: kube-scheduler
    image: ${HYPERKUBE_IMAGE_REPO}/kube-scheduler-amd64:$K8S_VER
    command:
    - /usr/local/bin/kube-scheduler
    - --master=https://${ADVERTISE_IP}
    - --leader-elect=true
    - --kubeconfig=/etc/kubernetes/scheduler-kubeconfig.yaml
    resources:
      requests:
        cpu: 100m
    livenessProbe:
      httpGet:
        host: 127.0.0.1
        path: /healthz
        port: 10251
      initialDelaySeconds: 15
      timeoutSeconds: 15
    volumeMounts:
    - mountPath: /etc/kubernetes/ssl
      name: "etc-kube-ssl"
      readOnly: true
    - mountPath: /etc/kubernetes/scheduler-kubeconfig.yaml
      name: "kubeconfig"
      readOnly: true
  volumes:
  - name: "etc-kube-ssl"
    hostPath:
      path: "/etc/kubernetes/ssl"
  - name: "kubeconfig"
    hostPath:
      path: "/etc/kubernetes/scheduler-kubeconfig.yaml"
EOF
