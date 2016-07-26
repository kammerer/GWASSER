FROM ubuntu:16.04

LABEL ubuntu.version="16.04" R.version="3.3.0" lme4.version="1.1.12" argparse.version="1.0.1" dplyr.version="0.4.3" ggplot2.version="2.1.0" lmerTest.version="2.0.32"

MAINTAINER Alice Minotto @ Earlham Institute

USER root

RUN sh -c 'echo "deb http://cran.rstudio.com/bin/linux/ubuntu trusty/" >> /etc/apt/sources.list' && \
        gpg --keyserver keyserver.ubuntu.com --recv-key E084DAB9 && \
        gpg -a --export E084DAB9 | apt-key add - && \
        apt-get -y update && apt-get -y install r-base && \
        R -e 'install.packages("lme4", repos="https://cloud.r-project.org/")' && \
        R -e 'install.packages("argparse", repos="https://cloud.r-project.org/")' && \
        R -e 'install.packages("dplyr", repos="https://cloud.r-project.org/")' && \
        R -e 'install.packages("ggplot2", repos="https://cloud.r-project.org/")' && \
        R -e 'install.packages("lmerTest", repos="https://cloud.r-project.org/")'

ADD https://raw.githubusercontent.com/cyverseuk/GWASSER/master/GWASSER.R /bin/

WORKDIR /data/

ENTRYPOINT ["Rscript", "/bin/GWASSER.R"]
