### Tutorial: Pipeline Creation using the Kale SDK

This tutorial walks you through the process of creating a Rok-enhanced Kubeflow Pipeline.

1. Create a new notebook server using this custom image: `tbaums/kale-sdk`
  - Please note: This image will move to Arrikto's GCR shortly. You will need to update your manifests to use the new image.
2. Launch a Terminal from the New Launcher tab.
3. Download the Kale SDK example from GitHub.
  - `curl -O https://raw.githubusercontent.com/tbaums/ml-sandbox/main/tutorial-kale-sdk/kale-sdk-pipeline-cpu.py`
4. Run the example.
  - 'python3 kale-sdk-pipeline-cpu.py --kfp`