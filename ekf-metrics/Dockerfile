FROM gcr.io/arrikto/jupyter-kale:4a5d7e63-9f74f267	
USER root
RUN echo "alias l='ls -alh'" >> /etc/bash.bashrc
RUN pip3 install --user kubernetes 
ADD ekf-metrics.py ./
CMD ["sh", "-c", "kubectl get po -A"]