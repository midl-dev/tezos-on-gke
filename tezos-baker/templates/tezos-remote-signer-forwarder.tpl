apiVersion: v1
kind: Service
metadata:
  name: tezos-remote-signer-forwarder
spec:
  type: NodePort
  ports:
  - port: 8443
    # signer is not meant to be accessed externally; I'd rather not set this but it's mandatory
    # it's fine because the firewall on the nodes won't take connections
    targetPort: 8443
    name: remote-signer
  - port: 58255
    targetPort: 58255
    name: ssh-forwarding-ingress
  selector:
    app: tezos-remote-signer-forwarder
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tezos-remote-signer-forwarder
spec:
  selector:
    matchLabels:
      app: tezos-remote-signer-forwarder
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: tezos-remote-signer-forwarder
    spec:
      securityContext:
        fsGroup: 100
      containers:
      - name: tezos-remote-signer-forwarder
        image: gcr.io/{{ .Values.gcloudProject }}/tezos-remote-signer-forwarder:v23
        ports:
        - containerPort: 58255
          name: ssh
        - containerPort: 8443
          name: signer
