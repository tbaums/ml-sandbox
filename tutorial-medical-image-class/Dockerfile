FROM gcr.io/arrikto/jupyter-kale:4a5d7e63-9f74f267
USER root
RUN echo "alias l='ls -alh'" >> /etc/bash.bashrc
RUN mkdir /home/tmp
RUN chown jovyan /home/tmp
WORKDIR /home/tmp
ADD requirements.txt ./
USER jovyan 
CMD ["sh", "-c", "cp /home/tmp/* /home/jovyan/; \
    pip3 install -r /home/jovyan/requirements.txt; \
    mkdir /home/jovyan/data; \
    gsutil cp gs://mtanenbaum/tutorial-medical-image-class/breast-histopathology-images.zip /home/jovyan/data; \
    jupyter lab --notebook-dir=/home/jovyan --ip=0.0.0.0 \
    --no-browser --allow-root --port=8888 --LabApp.token='' \
    --LabApp.password='' --LabApp.allow_origin='*' \
    --LabApp.base_url=${NB_PREFIX}"]