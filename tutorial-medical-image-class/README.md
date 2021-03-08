# Codelab Tutorial: Medical Image Classification for Disease Diagnosis

- Launch notebook server using image below:
  - `tbaums/medical-image-tutorial:b39f38b-202103051617`
- Edit Workspace Volume size to `15Gb`
- In order to save notebook, need to annotate NGINX Ingress to allow for large payloads:
  - `kubectl annotate ingress -n istio-system istio-ingress nginx.ingress.kubernetes.io/proxy-body-size=8m --overwrite`

