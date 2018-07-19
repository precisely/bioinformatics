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
  less \
  rlwrap \
  silversearcher-ag \
  time \
  unzip \
  vim \
  uuid-runtime

# programming environments
RUN apt-get install -y \
  cmake \
  openjdk-8-jre-headless \
  libc++-dev

# bioinformatics packages
RUN apt-get install -y \
  bcftools \
  samtools \
  tabix

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
# make bash suck slightly less
RUN echo '\n\
alias v="ls -la"\n\
alias ..="cd .."\n\
shopt -s autocd\n' >> .bashrc
# fix permissions
RUN chown docker:docker .tmux.conf

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
RUN \
  wget -O 23andme-datasets.html "https://my.pgp-hms.org/public_genetic_data?data_type=23andMe"
# This link extraction code should really use a proper HTML parser instead of awk.
RUN \
  awk -F'"' '/download/ { print $2 }' 23andme-datasets.html \
    | shuf --random-source=23andme-datasets.html \
    | awk '{ print "https://my.pgp-hms.org" $1 }' \
    | tee 23andme-dataset-URLs.txt \
    | head > 23andme-dataset-URLs-sample.txt
RUN wget -i 23andme-dataset-URLs-sample.txt
RUN \
  for file in `ls`; do \
    if file $file | grep Zip; then \
      unzip $file; \
    fi; \
  done
RUN \
  for file in `ls`; do \
    if file $file | grep ASCII; then \
      tr -d '\r' < $file > `basename $file .txt | sed 's/_/-/g'`_`md5sum $file | cut -d' ' -f 1`.txt; \
      rm $file; \
    fi; \
  done
RUN \
  rm -f 23andme-dataset-URLs-sample.txt 23andme-dataset-URLs.txt 23andme-datasets.html

# install beagle-leash (which seems to also install Beagle)
WORKDIR /precisely
RUN git clone https://bitbucket.org/taltman1/beagle-leash.git
WORKDIR /precisely/beagle-leash
# The beagle-leash install step should run as the unprivileged user because it
# does dumb things with .bashrc.
RUN make install-nodata

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
