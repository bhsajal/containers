FROM perl:5.38

WORKDIR /opt/tatfinder
COPY repo/ /opt/tatfinder/repo/
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/run_tatfinder.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
