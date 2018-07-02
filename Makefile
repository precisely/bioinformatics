## Downloaded from the following location:
## wget ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/technical/reference/human_g1k_v37.fasta.gzi
##
## Necessary to decompress and recompress using bgzip:
## bgzip <(zcat human_g1k_v37.fasta.gz) --stdout > human_g1k_v37.fasta.bgz
## aws s3 cp human_g1k_v37.fasta.bgz "s3://precisely-bio-dbs/human-1kg-v37/2010-05-17/"

## All recipe lines in one shell:
.ONESHELL:

## If any recipe errors, delete the target file:
.DELETE_ON_ERROR:


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


install: $(CURDIR)/ref-data/human_g1k_v37.fasta.bgz $(CURDIR)/ref-data/beagle-refdb/chr9.1kg.phase3.v5a.bref third-party/beagle-leash/.gitignore python-install
	@echo Installation complete!

reinstall-beagle-leash:
	rm -rf third-party/beagle-leash
	$(MAKE) third-party/beagle-leash/.gitignore

third-party/beagle-leash/.gitignore:
	mkdir -p third-party
	cd third-party \
		&& git clone https://taltman1@bitbucket.org/taltman1/beagle-leash.git \
		&& $(MAKE) -C beagle-leash --file=Makefile install-nodata

python-install:
	python  -m pip install \
		--user \
		--trusted-host pypi.python.org \
		.

### Docker workflows:

## All installation steps that should be performed at docker build time go here:
docker-install: reinstall-beagle-leash python-install

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

test-pipeline: test/ref/example-chr21-23andme.txt 
	export BEAGLE_REFDB_PATH="$(CURDIR)/ref-data/beagle-refdb"
	export TMPDIR="/dev/shm"
	export PATH="$(CURDIR)/third-party/beagle-leash/inst/beagle-leash/bin:$(PATH)"
	export BEAGLE_LEASH_CHROMS="21"
	python convert23andme/test_pipeline.py `ls test/pgp-samples | head -n 1`

test/23andme-datasets.html:
	mkdir -p test
	cd test
	wget -O 23andme-datasets.html "https://my.pgp-hms.org/public_genetic_data?data_type=23andMe"

test/23andme-dataset-URLs.txt: test/23andme-datasets.html
	mkdir -p test
	awk -F'"' '/download/ { print $$2 }' $^ \
		| shuf --random-source=$^ \
		| awk '{ print "https://my.pgp-hms.org" $$1 }' \
		| tee $@ \
		| head > test/23andme-dataset-URLs-sample.txt

#test/pgp-samples/447: 

test/pgp-samples/.done: test/23andme-dataset-URLs.txt
	mkdir -p test/pgp-samples
	cd test/pgp-samples
	wget -i ../23andme-dataset-URLs-sample.txt
	for file in `ls`
	do
		if file $$file | grep Zip
		then
			unzip $$file
		fi
	done	
	for file in `ls`
	do
		if file $$file | grep ASCII
		then
			tr -d '\r' < $$file > `basename $$file .txt | sed 's/_/-/g'`_`md5sum $$file | cut -d' ' -f 1`.txt
			rm $$file
		fi
	done
	touch .done

test-ten-samples: test/pgp-samples/.done
	export BEAGLE_REFDB_PATH="$(CURDIR)/ref-data/beagle-refdb"
	export TMPDIR="/dev/shm"
	export PATH="$(CURDIR)/third-party/beagle-leash/inst/beagle-leash/bin:$(PATH)"
	python convert23andme/test_pipeline.py `ls test/pgp-samples/* | shuf`

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
