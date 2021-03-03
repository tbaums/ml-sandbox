# Demo: COVID-19 Vaccine: mRNA Degradation Prediction w/Serving

## Overview

Demo runtime: 10 mins
Demo preptime: 60 mins **minimum**

This demo showcases:
- JWA: Self-service notebook provisioning for end users (data scientists/data engineers)
- Kale UI: Kale automation for pipeline creation and hyperparameter optimization with Katib via Kale UI
- Rok: Automated snapshotting for each pipeline step
- KFServing: Self-service deployment of models by end users; Models UI features for logging and monitoring.
- Rok Registry: Portability of complete environments with internal or external collaborators.

## Pre-demo preparation

1. Create 2 instances of MiniKF, each in a different GCP region.
1. Once fully deployed, log in to both instances and change cookie to remove `Strict`. This is required to prevent an auth infinite loop when connecting to Registry.
  - Right click...
1. Cluster 1: Launch a new notebook server called `vaccine-demo `using the custom image below:
  - `tbaums/vaccine-demo:2021-03-02`
1. Cluster 1: Launch a second new notebook server called `vaccine-serve` using the custom image below:
  - `tbaums/vaccine-demo:2021-03-02`
1. Cluster 1: Create a new published Rok bucket called `vaccine-shared` and complete connect and publish process with your Registry instance.
1. Cluster 1: Confirm `vaccine-demo` and `vaccine-serve` notebooks have deployed successfully, then run the commands below to move the demo files into the notebooks' $HOME directories (See footnote [1] below):
  - `kubectl exec -it -n kubeflow-user vaccine-demo-0 -- cp -a /home/tmp/. /home/jovyan/`
  - `kubectl exec -it -n kubeflow-user vaccine-serve-0 -- cp -a /home/tmp/. /home/jovyan/`
1. Cluster 1: Open the `vaccine-serve` notebook server 
  - Open `vaccine-degradation-serve.ipynb` notebook file from 

## Footnotes
1. We must move the demo files _after_ deploying the notebook server because the Jupyter file explerer UI can only display subdirectories and files in `/home/jovyan`. This is also the mount point for the Rok PVC. If we use the Dockerfile to move the files to `/home/jovyan` when building the image, they will be overwritten by the clean PVC mounted to `/home/jovyan`.
