## I forget whether the version that you download is GZip'ed or BGzip'ed.
## Might be necessary to decompress and recompress using bgzip.

### Installation:

$(CURDIR)/ref-data/human_g1k_v37.fasta.gz:
	mkdir -p $(CURDIR)/ref-data
	cd $(CURDIR)/ref-data \
		&& aws s3 cp "s3://precisely-bio-dbs/human-1kg-v37/2010-05-17/human_g1k_v37.fasta.gz" .
#	wget ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/technical/reference/human_g1k_v37.fasta.gzi
#	wget ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/technical/reference/human_g1k_v37.fasta.fai

$(CURDIR)/ref-data/beagle-refdb/chr9.1kg.phase3.v5a.bref:
	mkdir -p $(CURDIR)/ref-data/beagle-refdb
	aws s3 sync "s3://precisely-bio-dbs/beagle-1kg-bref/b37.bref" $(CURDIR)/ref-data/beagle-refdb

install: $(CURDIR)/ref-data/human_g1k_v37.fasta.gz $(CURDIR)/ref-data/beagle-refdb/chr9.1kg.phase3.v5a.bref third-party/beagle-leash/Makefile
	@echo Installation complete!

third-party/beagle-leash/Makefile:
	mkdir -p third-party
	cd third-party \
		&& git clone https://taltman1@bitbucket.org/taltman1/beagle-leash.git \
		&& cd beagle-leash \
		&& make install-nodata


### Docker workflows:

## All installation steps that should be performed at docker build time go here:
docker-install:
	pip install --trusted-host pypi.python.org .

## Build the docker image for the bioinformatics repository:
build-docker-image:
	docker build -t dev/precisely-bioinformatics .

# clean-docker-context:
# 	rm -rf /dev/shm/docker-context



### Tests

test-convert23andme:
	python ./convert23andme/test_convert23andme.py

test: test-convert23andme

test-beagle-leash:
	export BEAGLE_REFDB_PATH="$(CURDIR)/ref-data/beagle-refdb" \
		&& export TMPDIR="/dev/shm" \
		&& export PATH="$(PATH):$(CURDIR)/third-party/beagle-leash/inst/beagle-leash/bin" \
		&& cd third-party/beagle-leash \
		&& make test

### Cleaning UP

## This leaves data downloads intact
clean-software:
	rm -rf third-party/beagle-leash

clean-all: clean-software
	rm -rf $(CURDIR)/ref-data
