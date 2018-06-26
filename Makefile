## Downloaded from the following location:
## wget ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/technical/reference/human_g1k_v37.fasta.gzi
##
## Necessary to decompress and recompress using bgzip:
## bgzip <(zcat human_g1k_v37.fasta.gz) --stdout > human_g1k_v37.fasta.bgz
## aws s3 cp human_g1k_v37.fasta.bgz "s3://precisely-bio-dbs/human-1kg-v37/2010-05-17/"

.ONESHELL:

### Installation:

$(CURDIR)/ref-data/human_g1k_v37.fasta.bgz:
	mkdir -p $(CURDIR)/ref-data
	cd $(CURDIR)/ref-data
	aws s3 cp "s3://precisely-bio-dbs/human-1kg-v37/2010-05-17/human_g1k_v37.fasta.bgz" .
	aws s3 cp "s3://precisely-bio-dbs/human-1kg-v37/2010-05-17/human_g1k_v37.fasta.bgz.gzi" .
	aws s3 cp "s3://precisely-bio-dbs/human-1kg-v37/2010-05-17/human_g1k_v37.fasta.bgz.fai" .	

#	
#	wget ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/technical/reference/human_g1k_v37.fasta.fai


$(CURDIR)/ref-data/beagle-refdb/chr9.1kg.phase3.v5a.bref:
	mkdir -p $(CURDIR)/ref-data/beagle-refdb
	aws s3 sync "s3://precisely-bio-dbs/beagle-1kg-bref/b37.bref" $(CURDIR)/ref-data/beagle-refdb


install: $(CURDIR)/ref-data/human_g1k_v37.fasta.gz $(CURDIR)/ref-data/beagle-refdb/chr9.1kg.phase3.v5a.bref third-party/beagle-leash/Makefile
	@echo Installation complete!

reinstall-beagle:
	rm -rf third-party/beagle-leash
	$(MAKE) third-party/beagle-leash/.gitignore

third-party/beagle-leash/.gitignore:
	mkdir -p third-party
	cd third-party \
		&& git clone https://taltman1@bitbucket.org/taltman1/beagle-leash.git \
		&& $(MAKE) -C beagle-leash --file=Makefile install-nodata


### Docker workflows:

## All installation steps that should be performed at docker build time go here:
docker-install:
	python  -m pip install \
		--user $(USER) \
		--trusted-host pypi.python.org \
		.

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

test-pipeline:
	export BEAGLE_REFDB_PATH="$(CURDIR)/ref-data/beagle-refdb"
	export TMPDIR="/dev/shm"
	export PATH="$(CURDIR)/third-party/beagle-leash/inst/beagle-leash/bin:$(PATH)"
	export BEAGLE_LEASH_CHROMS="21"
	python convert23andme/test_pipeline.py


### Cleaning Up

## This leaves data downloads intact
clean-software:
	rm -rf third-party/beagle-leash

clean-all: clean-software
	rm -rf $(CURDIR)/ref-data


### Data Staging
### (this only needs to be run roughly once a year)

stage-data:

test/ref/example-chr21-23andme.txt:
	mkdir -p test/ref
	cd test/ref
	wget -O example-23andme.zip https://my.pgp-hms.org/user_file/download/3511
	unzip example-23andme.zip
	rm example-23andme.zip
	mv *_v5_Full_*.txt example-23andme_deadbeef.txt
	awk -F"\t" '/^#/ || $$2 == 21' example-23andme_deadbeef.txt > example-chr21-23andme_deadbeef.txt
