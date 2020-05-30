FROM polynote/polynote:0.3.7-2.12-spark2.4

COPY /config.yml /opt/config/config.yml

RUN touch /opt/polynote/notebooks/BlankNotebook.ipynb

CMD ["--config /opt/config/config.yml"]
