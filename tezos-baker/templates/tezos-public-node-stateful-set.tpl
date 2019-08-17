kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: local-ssd
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-ssd
---
apiVersion: v1
kind: Service
metadata:
  name: tezos-public-node
spec:
  ports:
  - port: 9732
  selector:
    app: tezos-public-node
  clusterIP: None
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: tezos-public-node
spec:
  selector:
    matchLabels:
      app: tezos-public-node # Label selector that determines which Pods belong to the StatefulSet
                 # Must match spec: template: metadata: labels
  serviceName: "tezos-public-node"
  replicas: 2
  template:
    metadata:
      labels:
        app: tezos-public-node # Pod template's label selector
    spec:
      securityContext:
        fsGroup: 100
      containers:
      - name: tezos-public-node
        image: tezos/tezos:alphanet
        args: [ "tezos-node", "--disable-mempool" ]
        ports:
        - containerPort: 9732
          name: tezos-port
        volumeMounts:
        - name: tezos-public-node-pv-claim
          mountPath: /var/run/tezos/node
      initContainers:
      - name: tezos-chain-downloader
        image: gcr.io/{{ .Values.gcloudProject }}/tezos-chain-downloader:latest
        args:
        - "$(SNAPSHOT_URL)"
        env:
        - name: SNAPSHOT_URL
          valueFrom:
            configMapKeyRef:
              name: {{ .Release.Name }}-configmap
              key: SNAPSHOT_URL
        volumeMounts:
        - name: tezos-public-node-pv-claim
          mountPath: /var/run/tezos/node
  volumeClaimTemplates:
  - metadata:
      name: tezos-public-node-pv-claim
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: local-ssd
      resources:
        requests:
          storage: 100Gi
