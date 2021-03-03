FROM gcr.io/arrikto/jupyter-kale:4a5d7e63-9f74f267
USER root
RUN echo "alias l='ls -alh'" >> /etc/bash.bashrc
RUN mkdir /home/tmp
RUN chown jovyan /home/tmp
WORKDIR /home/tmp
ADD * ./
RUN pip3 install --upgrade pip
USER joyvan 
RUN pip3 install -r requirements.txt --target=/usr/local/bin
RUN rm ./Dockerfile
RUN rm ./docker-build-and-push.sh