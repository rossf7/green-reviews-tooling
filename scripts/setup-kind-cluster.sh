#!/bin/bash

flux install

kubectl apply -f clusters/base/monitoring-namespace.yaml
kubectl apply -f clusters/base/

sleep 20

flux reconcile helmrelease -n flux-system kepler

kubectl wait pod \
--all \
--for=condition=Ready \
--namespace monitoring
