kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: repd-central1-b-f
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-ssd
  replication-type: regional-pd
  zones: us-central1-b, us-central1-f
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: tezos-private-node-claim
spec:
  storageClassName: repd-central1-b-f
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: tezos-private-client-claim
spec:
  storageClassName: repd-central1-b-f
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Service
metadata:
  name: tezos-private-node
spec:
  ports:
  - port: 9732
  selector:
    app: tezos-private-node
  clusterIP: None
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tezos-private-baking-node-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: tezos-private-baking-node
  policyTypes:
  - Ingress
  - Egress
  egress:
  - ports:
    - port: 53
      protocol: TCP
    - port: 53
      protocol: UDP
  - ports:
    - port: 9732
      protocol: TCP
    to:
    - podSelector:
        matchLabels:
          app: tezos-public-node
  ingress:
  - ports:
    - port: 53
      protocol: TCP
    - port: 53
      protocol: UDP
  - ports:
    - port: 9732
      protocol: TCP
    from:
    - podSelector:
        matchLabels:
          app: tezos-public-node
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tezos-private-baking-node
spec:
  selector:
    matchLabels:
      app: tezos-private-baking-node
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: tezos-private-baking-node
    spec:
      securityContext:
        fsGroup: 100
      containers:
      - name: tezos-private-node
        image: tezos/tezos:alphanet
        args: [ "tezos-node", "--private-mode", "--peer", "tezos-public-node-0.tezos-public-node", "--peer", "tezos-public-node-1.tezos-public-node", "--connections", "2" ]
        ports:
        - containerPort: 9732
          name: tezos-port
        volumeMounts:
        - name: tezos-private-node-storage
          mountPath: /var/run/tezos/node
      - name: tezos-endorser-with-remote-signer
        image: gcr.io/{{ .Values.gcloudProject }}/tezos-endorser-with-remote-signer:v7
        args: [ "k8s-baker" ]
        volumeMounts:
        - name: tezos-private-node-storage
          readOnly: true
          mountPath: /var/run/tezos/node
        - name: tezos-private-client-storage
          mountPath: /var/run/tezos/client
        envFrom:
        - configMapRef:
            name: {{ .Release.Name }}-baker-configmap
      - name: tezos-accuser
        image: tezos/tezos:alphanet
        args: [ "tezos-accuser" ]
        env:
        - name: NODE_HOST
          valueFrom:
            configMapKeyRef:
              name: {{ .Release.Name }}-baker-configmap
              key: NODE_HOST
        - name: PROTOCOL
          valueFrom:
            configMapKeyRef:
              name: {{ .Release.Name }}-baker-configmap
              key: PROTOCOL
        volumeMounts:
        - name: tezos-private-client-storage
          readOnly: true
          mountPath: /var/run/tezos/client
      - name: tezos-baker-with-remote-signer
        image: gcr.io/{{ .Values.gcloudProject }}/tezos-baker-with-remote-signer:v9
        args: [ "k8s-baker" ]
        volumeMounts:
        - name: tezos-private-node-storage
          readOnly: true
          mountPath: /var/run/tezos/node
        - name: tezos-private-client-storage
          mountPath: /var/run/tezos/client
        envFrom:
        - configMapRef:
            name: {{ .Release.Name }}-baker-configmap
      initContainers:
      - name: import-baking-key
        image: tezos/tezos:alphanet
        # -f is to force key re-import (in case it's already here)
        args: [ "tezos-client", "import", "secret", "key", "k8s-baker", "http://tezos-remote-signer-forwarder:8443/$(PUBLIC_BAKING_KEY)", "-f" ]
        env:
        - name: PUBLIC_BAKING_KEY
          valueFrom:
            configMapKeyRef:
              name: {{ .Release.Name }}-configmap
              key: PUBLIC_BAKING_KEY
        volumeMounts:
        - name: tezos-private-client-storage
          mountPath: /var/run/tezos/client
      - name: tezos-chain-downloader
        image: gcr.io/{{ .Values.gcloudProject }}/tezos-chain-downloader:v9
        args:
        - "$(SNAPSHOT_URL)"
        env:
        - name: SNAPSHOT_URL
          valueFrom:
            configMapKeyRef:
              name: {{ .Release.Name }}-configmap
              key: SNAPSHOT_URL
        volumeMounts:
        - name: tezos-private-node-storage
          mountPath: /var/run/tezos/node
      volumes:
      - name: tezos-private-client-storage
        persistentVolumeClaim:
          claimName: tezos-private-client-claim
      - name: tezos-private-node-storage
        persistentVolumeClaim:
          claimName: tezos-private-node-claim
