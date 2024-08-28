ARG ERIC_ENM_PMSDK_IMAGE_NAME=eric-enm-pmsdk
ARG ERIC_ENM_PMSDK_IMAGE_REPO=REPLACE-REPO
ARG ERIC_ENM_PMSDK_IMAGE_TAG=1.22.0-30

FROM ${ERIC_ENM_PMSDK_IMAGE_REPO}/${ERIC_ENM_PMSDK_IMAGE_NAME}:${ERIC_ENM_PMSDK_IMAGE_TAG}


RUN /bin/mkdir -p /ericsson/credm/data/xmlfiles && \
    /bin/chown -R jboss_user:jboss /ericsson/credm/data/xmlfiles && \
    /bin/chmod -R 755 /ericsson/credm/data/xmlfiles
	

ENV SECURE_PORT=59010 UNSECURE_PORT=59001

# The mediation service capability for customized nodes, default value is 'generic3pp'
# If changed, must match the same parameter provided in: 'pm-mediation-router-policy-archetype'
#  See "ENM PM Customization for SNMP Network Elements" (1/155 42-CRA 119 1917)
#    Chapter "Use the SDK Archetype - pm-mediation-router-policy-archetype"
ENV sgCapability="generic3pp"

RUN echo "JAVA_OPTS=\"\$JAVA_OPTS -Dcm_securePort=\$SECURE_PORT -Dcm_unsecurePort=\$UNSECURE_PORT\"" >> /ericsson/3pp/jboss/bin/standalone.conf


ENV ARCHETYPE_RPMS /var/tmp/rpms

RUN mkdir -p ${ARCHETYPE_RPMS}

COPY image_content/*.rpm ${ARCHETYPE_RPMS}/

RUN cd ${ARCHETYPE_RPMS} && if ls *.rpm > /dev/null 2>&1; then zypper --no-gpg-checks --non-interactive install *.rpm ;fi

RUN cd ${ARCHETYPE_RPMS} && rm -rf *.rpm


#############################################
# Workaround for Credential Manager CLI
 #############################################


EXPOSE 12987 50558 50691 52679 53689 54402 54502 55181 55502 55511 55571 56231 56234 58170 58171 58172 59001 59010
