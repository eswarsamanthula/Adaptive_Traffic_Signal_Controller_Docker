FROM nodered/node-red:5.0.9

USER root
COPY package.json /tmp/package.json
RUN cp /tmp/package.json /data/package.json \
    && npm install --prefix /data --unsafe-perm --no-audit --no-fund \
    && rm /tmp/package.json
COPY --chown=1000:1000 flows.json /data/flows.json
USER node-red
