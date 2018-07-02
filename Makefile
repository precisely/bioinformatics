## I forget whether the version that you download is GZip'ed or BGzip'ed.
## Might be necessary to decompress and recompress using bgzip.
build-human-genome-ref-db:
	mkdir -p $(HOME)/data
	cd $(HOME)/data
	wget -c ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/technical/reference/human_g1k_v37.fasta.gz
	#wget ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/technical/reference/human_g1k_v37.fasta.gzi
	wget -c ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/technical/reference/human_g1k_v37.fasta.fai
	#added -c option to prevent double downloading. fasta.gzi gets No such file error, commented out for now


install: build-human-genome-ref-db AncestryDNA.txt
	echo
	#Make sure the ucsc gene symbols/etc are downloaded?

build-docker-image: install
	echo

test-convert23andme:
	python ./convert23andme/test_convert23andme.py


AncestryDNA.txt: 
	mkdir -p convert_ancestry/test
	wget -O convert_ancestry/test/ancestry-sample.zip -c https://my.pgp-hms.org/user_file/download/3433
	unzip -n convert_ancestry/test/ancestry-sample.zip -d convert_ancestry/test

test: install #test-convert23andme
	mamba convert_ancestry/test_convert_ancestry.py && \
	python convert_ancestry/convert_ancestry.py convert_ancestry/test/AncestryDNA.txt
	#mamba test_ancestry_to_vcf.py

setup-test: 
	pip install mamba
	pip install expects

clean: 	
	rm -rf human_g1k_v37.* || true
	rm -r convert_ancestry/test || true