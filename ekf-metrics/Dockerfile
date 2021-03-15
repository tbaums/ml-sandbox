FROM python:3.8
USER root
RUN echo "alias l='ls -alh'" >> /etc/bash.bashrc
RUN mkdir -p $HOME/.kube 
ADD ./config $HOME/.kube/
ADD ./client* $HOME/.kube/
RUN pip3 install --user kubernetes 
ADD ekf-metrics.py ./
CMD ["python3", "ekf-metrics.py"]