# ml-sandbox

### To demo secrets in KFP w/Kale:

To make this clear as best I could, I went ahead and made a mini tutorial.

First, run these commands:


`kubectl create secret generic secret1 -n kubeflow-user --from-literal=secret-key=secret-contents`

`kubectl create secret generic secret2 -n kubeflow-user --from-literal=secret-key=secret-contents2`

`kubectl get secret -n kubeflow-user`

```
cat <<EOF | kubectl create -f -
apiVersion: "kubeflow.org/v1alpha1"
kind: PodDefault
metadata:
  name: add-secret-1
  namespace: kubeflow-user
spec:
 selector:
  matchLabels:
    add-secret1: "true"
 desc: "add secret1 credential"
 volumeMounts:
 - name: secret1-volume
   mountPath: /secret/secret1
 volumes:
 - name: secret1-volume
   secret:
     secretName: secret1
EOF
```

```
cat <<EOF | kubectl create -f -
apiVersion: "kubeflow.org/v1alpha1"
kind: PodDefault
metadata:
  name: add-secret-2
  namespace: kubeflow-user
spec:
 selector:
  matchLabels:
    add-secret2: "true"
 desc: "add secret2 credential"
 env:
   - name: SECRET2
     valueFrom:
       secretKeyRef:
          name: secret2
          key: secret-key
EOF
```


Next, launch a new nb server with both secrets selected. Then, pull down this example notebook (`curl -O https://raw.githubusercontent.com/tbaums/ml-sandbox/main/secrets_demo.ipynb`). 

Open that notebook, and enable Kale in the left-hand panel.

Click "compile and run" and follow the link to the pipeline that gets generated.

If you look at the logs for each pipeline step, you'll see that the secret is available in that step.

Basically, the way pod defaults work is that before the pod gets created, there is a check to see if that pod has certain labels on it (which is why there is a matchLabels section in the PodDefault yaml). If the pod does have the labels, then the controller injects the stuff below (mounts or env vars), etc. When you launch a notebook and you select the checkbox, you are saying to the notebook launcher that you want your notebook to launch with those labels on it so the controller injects the stuff you want
