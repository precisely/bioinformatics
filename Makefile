## I forget whether the version that you download is GZip'ed or BGzip'ed.
## Might be necessary to decompress and recompress using bgzip.

### Installation:

$(HOME)/data/human_g1k_v37.fasta.gz:
	mkdir -p $(HOME)/data
	cd $(HOME)/data \
		aws s3 cp "s3://precisely-bio-dbs/human-1kg-v37/2010-05-17/human_g1k_v37.fasta.gz" .
#	wget ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/technical/reference/human_g1k_v37.fasta.gzi
#	wget ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/technical/reference/human_g1k_v37.fasta.fai

$(HOME)/data/beagle-refdb/chr9.1kg.phase3.v5a.bref:
	mkdir -p $(HOME)/data/beagle-refdb
	aws s3 sync "s3://precisely-bio-dbs/beagle-1kg-bref/b37.bref" $(HOME)/data/beagle-refdb

install: $(HOME)/data/human_g1k_v37.fasta.gz $(HOME)/data/beagle-refdb/chr9.1kg.phase3.v5a.bref third-party/beagle-leash/Makefile
	@echo Installation complete!

third-party/beagle-leash/Makefile:
	mkdir -p third-party
	cd third-party \
		&& git clone https://taltman1@bitbucket.org/taltman1/beagle-leash.git \
		&& cd beagle-leash \
		&& make install-nodata

### Docker workflows:

build-docker-image: install
	echo


### Tests

test-convert23andme:
	python ./convert23andme/test_convert23andme.py

test: test-convert23andme

test-beagle-leash:
	export BEAGLE_REFDB_PATH="$(HOME)/data/beagle-refdb" \
		&& export TMPDIR="/dev/shm" \
		&& export PATH="$(PATH):$(CURDIR)/third-party/beagle-leash/inst/beagle-leash/bin" \
		&& cd third-party/beagle-leash \
		&& make test

### Cleaning UP

## This leaves data downloads intact
clean-software:
	rm -rf third-party/beagle-leash

clean-all: clean-software
	rm -rf $(HOME)/data
