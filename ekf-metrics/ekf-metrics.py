from kubernetes import client, config
import kubernetes 
from kubernetes.client.rest import ApiException

# Configs can be set in Configuration class directly or using helper utility
configuration = kubernetes.client.Configuration()

configuration.host = "https://10.96.0.1" # set to kubernetes API server cluster IP

# Enter a context with an instance of the API kubernetes.client
with kubernetes.client.ApiClient(configuration) as api_client:
    api_instance = kubernetes.client.AdmissionregistrationApi(api_client)
    
    try:
        api_response = api_instance.get_api_group()
        print(api_response)
    except ApiException as e:
        print("Exception when calling AdmissionregistrationApi->get_api_group: %s\n" % e)
    