## I forget whether the version that you download is GZip'ed or BGzip'ed.
## Might be necessary to decompress and recompress using bgzip.
#build-human-genome-ref-db:
#	mkdir -p $(HOME)/data
#	cd $(HOME)/data
#	wget ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/technical/reference/human_g1k_v37.fasta.gz
#	wget ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/technical/reference/human_g1k_v37.fasta.gzi
#	wget ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/technical/reference/human_g1k_v37.fasta.fai



#install: build-human-genome-ref-db
#	echo

#build-docker-image: install
#	echo

test-convert23andme:
	python ./convert23andme/test_convert23andme.py

test: test-convert23andme

AncestryDNA.txt: 
	mkdir convertAncestry/test
	wget -O convertAncestry/test/ancestry-sample.zip https://my.pgp-hms.org/user_file/download/3433
	unzip convertAncestry/test/ancestry-sample.zip

test: AncestryDNA.txt
	cd convertAncestry && \
	mamba convertAncestryTest.py \
	python convertAncestry.py test/AncestryDNA.txt

