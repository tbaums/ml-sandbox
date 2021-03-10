FROM gcr.io/arrikto/jupyter-kale:4a5d7e63-9f74f267
USER root
RUN echo "alias l='ls -alh'" >> /etc/bash.bashrc
# RUN mkdir /home/tmp
# RUN chown jovyan /home/tmp
RUN apt-get update
ADD *.ipynb ./
ADD requirements.txt ./
ADD data/images_sample.tar ./
ADD data/processed_images.pkl ./
# packages below are required for CV2 Python library
RUN apt-get install ffmpeg libsm6 libxext6  -y
RUN pip3 install -r requirements.txt
CMD ["sh", "-c", "jupyter lab --notebook-dir=/home/jovyan --ip=0.0.0.0 \
    --no-browser --allow-root --port=8888 --LabApp.token='' \
    --LabApp.password='' --LabApp.allow_origin='*' \
    --LabApp.base_url=${NB_PREFIX}"]