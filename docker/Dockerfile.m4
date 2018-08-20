m4_dnl This is an M4 template for a Dockerfile. It is necessary because we want to
m4_dnl use Docker in two modes: development and deployment. These modes are
m4_dnl fundamentally different, in that development should use a virtual folder to
m4_dnl house the code under development. That way, code can be edited outside the
m4_dnl container but run inside. Production mode should just contain a copy of the
m4_dnl code.
m4_dnl
m4_dnl Unfortunately, Dockerfile has no conditional support. The developers deem
m4_dnl this a feature. Luckily, 1977 tools can fix 2013 hipster technology.
m4_dnl
m4_dnl To generate a production Dockerfile, run it through the M4 preprocessor as
m4_dnl follows:
m4_dnl
m4_dnl   m4 -P Dockerfile.m4
m4_dnl
m4_dnl To generate a Dockerfile for development use, invoke M4 as follows:
m4_dnl
m4_dnl   m4 -P -Dmode=link Dockerfile.m4
m4_dnl
m4_dnl To run a docker build from a preprocessed Dockerfile, run this:
m4_dnl
m4_dnl   docker build -f - m4 -P Dockerfile.m4
m4_dnl
m4_changequote(`[[[', `]]]')m4_dnl
m4_dnl
m4_dnl
# Python 2.7 based on Debian Stretch (stable as of 2017-06-17)
FROM python:2.7-stretch

# update to the latest and greatest
RUN apt-get update

# system packages
RUN apt-get install -y \
  apt-utils \
  aptitude \
  autoconf \
  automake \
  build-essential \
  libtool \
  man-db \
  manpages \
  pkgconf \
  sudo

# basic utilities
RUN apt-get install -y \
  awscli \
  curl \
  emacs-nox \
  gawk \
  git-core \
  htop \
  jq \
  less \
  rlwrap \
  silversearcher-ag \
  sqlite3 \
  time \
  unzip \
  vim \
  uuid-runtime

# programming environments
RUN apt-get install -y \
  cmake \
  openjdk-8-jre-headless \
  maven \
  libc++-dev

# bioinformatics packages
RUN apt-get install -y \
  bcftools \
  samtools \
  tabix

# node requires a dedicated APT source on Debian; this is a dependency for LocalStack
RUN curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
RUN apt-get install -y nodejs

# the tmux package distributed with Debian is broken; install from source
RUN curl -L -O https://github.com/tmux/tmux/releases/download/2.7/tmux-2.7.tar.gz && \
  tar zxf tmux-2.7.tar.gz && \
  cd tmux-2.7 && \
  ./configure && \
  make install && \
  cd .. && \
  rm -rf tmux-2.7 tmux-2.7.tar.gz

# sane basic user setup
RUN useradd -m -s /bin/bash docker && \
  passwd docker -d
RUN echo 'ALL ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
WORKDIR /home/docker

# configure the internal docker user environment:
# download a tmux configuration
RUN curl -L -o .tmux.conf https://raw.githubusercontent.com/gcv/dotfiles/ddcd10e97939595911e2c2bfc5690a487ebac00a/public/tmux.conf
RUN chown docker:docker .tmux.conf
# make bash suck slightly less
RUN echo $'\n\
export PATH=${HOME}/.local/bin:${PATH}\n\n\
alias v="ls -la"\n\
alias ..="cd .."\n\
alias ...="cd ../.."\n\
alias ....="cd ../../.."\n\
alias .....="cd ../../../.."\n\n\
shopt -s autocd\n' >> .bashrc

# set up
ARG aws_access_key_id
ARG aws_secret_access_key
ENV AWS_ACCESS_KEY_ID ${aws_access_key_id}
ENV AWS_SECRET_ACCESS_KEY ${aws_secret_access_key}

# working area
WORKDIR /precisely
RUN chown docker:docker .
USER docker
RUN mkdir -p data data/beagle-refdb data/samples beagle-leash app

# download genome data
WORKDIR /precisely/data
RUN aws s3 cp "s3://precisely-bio-dbs/human-1kg-v37/2010-05-17/human_g1k_v37.fasta.bgz" .
RUN aws s3 cp "s3://precisely-bio-dbs/human-1kg-v37/2010-05-17/human_g1k_v37.fasta.bgz.gzi" .
RUN aws s3 cp "s3://precisely-bio-dbs/human-1kg-v37/2010-05-17/human_g1k_v37.fasta.bgz.fai" .
WORKDIR /precisely/data/beagle-refdb
RUN aws s3 sync "s3://precisely-bio-dbs/beagle-1kg-bref/b37.bref" .

# download testing data
# adapted from the old Makefile
WORKDIR /precisely/data/samples
#RUN \
#  wget -O 23andme-datasets.html "https://my.pgp-hms.org/public_genetic_data?data_type=23andMe"
# The link extraction code should really use a proper HTML parser instead of awk.
#RUN \
#  awk -F'"' '/user_file\/download/ { print $2 }' 23andme-datasets.html \
#    | awk '{ print "https://my.pgp-hms.org" $1 }' \
#    | tee 23andme-dataset-URLs.txt \
#    | shuf \
#    | head -20 > 23andme-dataset-URLs-sample.txt
# This downloads a randomly-chosen selection of sample 23andMe datasets, bad
# idea for a reproducible build:
#RUN wget --tries=3 -i 23andme-dataset-URLs-sample.txt
# Download a handful of pre-selected 23andMe datasets, including non-v37 genomes:
# NB: The following are unreliable, and so commented out.
#RUN wget --tries=3 https://my.pgp-hms.org/user_file/download/609
#RUN wget --tries=3 https://my.pgp-hms.org/user_file/download/1117
#RUN wget --tries=3 https://my.pgp-hms.org/user_file/download/1386
#RUN wget --tries=3 https://my.pgp-hms.org/user_file/download/1386
#RUN wget --tries=3 https://my.pgp-hms.org/user_file/download/1816
#RUN wget --tries=3 https://my.pgp-hms.org/user_file/download/1820
#RUN wget --tries=3 https://my.pgp-hms.org/user_file/download/302
#RUN wget --tries=3 https://my.pgp-hms.org/user_file/download/3507
#RUN wget --tries=3 https://my.pgp-hms.org/user_file/download/856
#RUN wget --tries=3 https://my.pgp-hms.org/user_file/download/1011
#RUN wget --tries=3 https://my.pgp-hms.org/user_file/download/1232
#RUN wget --tries=3 https://my.pgp-hms.org/user_file/download/151
#RUN wget --tries=3 https://my.pgp-hms.org/user_file/download/1821
#RUN wget --tries=3 https://my.pgp-hms.org/user_file/download/2017
#RUN wget --tries=3 https://my.pgp-hms.org/user_file/download/2024
# The following are standardized for testing purposes, and provided on our own
# S3 bucket:
RUN aws s3 cp --recursive "s3://precisely-bio-dbs/samples/23andme" 23andme
RUN aws s3 cp --recursive "s3://precisely-bio-dbs/samples/2018-08-16-imputation-run-abeeler-miniaturized" 2018-08-16-imputation-run-abeeler-miniaturized
# uncompress as needed
RUN \
  for file in `ls`; do \
    if file $file | grep Zip; then \
      unzip $file; \
      rm -f $file; \
    fi; \
  done

# install beagle-leash (which seems to also install Beagle)
WORKDIR /precisely
RUN git clone https://bitbucket.org/altmananalytics/beagle-leash.git
WORKDIR /precisely/beagle-leash
RUN make install-nodata
# The beagle-leash install step does bad things with .bashrc which require
# repair (it blindly overrides the PATH and does so incorrectly).
RUN grep -v 'export PATH=.*inst/beagle-leash/bin' ~/.bashrc > ~/.bashrc-tmp && mv ~/.bashrc-tmp ~/.bashrc
RUN sudo ln -s ln -s /precisely/beagle-leash/inst/beagle-leash/bin/beagle-leash /usr/local/bin

# TODO: Make optional for production?
# install local AWS clones: LocalStack, Minio, and DynamoDB Local
RUN sudo mkdir /precisely/aws-local && sudo chown docker:docker /precisely/aws-local
WORKDIR /precisely/aws-local
RUN mkdir -p conf/minio data/localstack data/minio data/dynamo
# LocalStack
RUN pip install --no-warn-script-location --user localstack==0.8.7
# Minio
RUN curl -L -O https://dl.minio.io/server/minio/release/linux-amd64/minio
RUN chmod +x minio
# DynamoDB Local
RUN mkdir dynamo
WORKDIR /precisely/aws-local/dynamo
RUN curl -L -O https://s3-us-west-2.amazonaws.com/dynamodb-local/dynamodb_local_latest.zip
RUN unzip dynamodb_local_latest.zip
RUN rm dynamodb_local_latest.zip
# add startup scripts
WORKDIR /precisely/aws-local
RUN echo '#!/usr/bin/env bash\n\n\
export HOSTNAME=localhost\n\
export DATA_DIR=/precisely/aws-local/data/localstack\n\
localstack start\n' >> localstack.sh
RUN chmod +x localstack.sh
RUN echo '#!/usr/bin/env bash\n\n\
export MINIO_ACCESS_KEY=access-key\n\
export MINIO_SECRET_KEY=secret-key\n\
export MINIO_BROWSER=off\n\
/precisely/aws-local/minio server --config-dir /precisely/aws-local/conf/minio /precisely/aws-local/data/minio\n' >> minio.sh
RUN chmod +x minio.sh
RUN echo '#!/usr/bin/env bash\n\n\
java -Djava.library.path=/precisely/aws-local/dynamo/DynamoDBLocal_lib -jar /precisely/aws-local/dynamo/DynamoDBLocal.jar -sharedDb -dbPath /precisely/aws-local/data/dynamo\n' >> dynamo.sh
RUN chmod +x dynamo.sh

# finally, set up the app
WORKDIR /precisely/app

# Temporarily copy in the requirements.txt file from the Python scripts area to
# install dependencies. This is necessary because that file is not yet available
# in the container, especially in link mode.
COPY python/requirements.txt .
RUN sudo pip install -r requirements.txt
RUN rm requirements.txt

m4_ifelse(mode, [[[link]]], [[[m4_dnl
# go; this container is meant to be connected to using tmux
CMD ["sh"]
]]], [[[m4_dnl
# Copy the current directory into the app; make sure it contains code intended
# for deployment!
COPY . /precisely/app

# run the app entry point script
CMD ["./run.sh"]
]]])m4_dnl
