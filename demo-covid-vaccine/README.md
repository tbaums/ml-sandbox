# Demo: COVID-19 Vaccine: mRNA Degradation Prediction w/Serving

## Overview

Demo runtime: 10 mins
Demo preptime: 60 mins **minimum**

This demo showcases:
- JWA: Self-service notebook provisioning for end users (data scientists/data engineers)
- Kale UI: Kale automation for pipeline creation and hyperparameter optimization with Katib via Kale UI
- Rok: Automated snapshotting for each pipeline step
- KFServing: Self-service deployment of models by end users; Models UI features for logging and monitoring.
- Rok Registry: Portability of complete environments to enable internal or external collaboratoration.

## Pre-demo preparation

1. Create 2 instances of MiniKF, each in a different GCP region.
1. Cluster 1 and Cluster 2: Once fully deployed, log in to both instances and change cookie to remove `Strict`. This is required to prevent an auth infinite loop when connecting to Registry.
    - On Chrome, right click on the Kubeflow UI and select "Inspect".
    - Select the "Application" tab from the DevTools window that opens.
    - In the Storage section in the left navigation bar, open the Cookies folder.
    - Select the cookie for your instance.
    - Double click the "SameSite" column for the `authservice_session` cookie, then hit backspace and enter. 
    - Refresh the page and confirm that hthe SameSite column remains blank.
1. Cluster 1: Launch a new notebook server called `vaccine-demo `using the custom image below:
    - `tbaums/vaccine-demo:2021-03-04`
1. Cluster 1: Launch a second new notebook server called `vaccine-serve` using the custom image below:
    - `tbaums/vaccine-demo:2021-03-04`
1. Cluster 1: Create a new published Rok bucket called `vaccine-shared` and complete connect and publish process with your Registry instance.
1. Cluster 1: Connect to the `vaccine-serve` notebook server 
    - Open `vaccine-degradation-serve.ipynb` notebook file from the file browser on left.
    - Select "Run" from the top menu, then "Run all cells."
1. Cluster 1: Connect to the `vaccine-demo` notebook server
    - Open `vaccine-degradation.ipynb` notebook file from the file browser on left.
    - Open Katib Jupyter extension.
    - Click "Enable" toggle.
    - Click "Compile and run Katib job"

<!-- ## Footnotes -->

