FROM ubuntu:16.04

USER root

RUN sh -c 'echo "deb http://cran.rstudio.com/bin/linux/ubuntu trusty/" >> /etc/apt/sources.list' && \
        gpg --keyserver keyserver.ubuntu.com --recv-key E084DAB9 && \
        gpg -a --export E084DAB9 | apt-key add - && \
        apt-get -y update && apt-get -y install r-base && \
        R -e 'install.packages("lme4", repos="https://cloud.r-project.org/")' && \
        R -e 'install.packages("argparse", repos="https://cloud.r-project.org/")' && \
        R -e 'install.packages("dplyr", repos="https://cloud.r-project.org/")' && \
        R -e 'install.packages("ggplot2", repos="https://cloud.r-project.org/")'

ADD https://raw.githubusercontent.com/cyverseuk/GWASSER/master/GWASSER.R /data/

WORKDIR /data/

ENTRYPOINT ["Rscript", "GWASSER.R"]
