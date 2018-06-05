## I forget whether the version that you download is GZip'ed or BGzip'ed.
## Might be necessary to decompress and recompress using bgzip.
human_g1k_v37.fasta.gz: #build-human-genome-ref-db:
	mkdir -p $(HOME)/data
	cd $(HOME)/data
	wget ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/technical/reference/human_g1k_v37.fasta.gz
	wget ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/technical/reference/human_g1k_v37.fasta.gzi
	wget ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/technical/reference/human_g1k_v37.fasta.fai
	aws cli s3 sync

build-human-genome-ref-db: human_g1k_v37.fasta.gz

install: 
	echo

build-docker-image: install
	echo

test-convert23andme:
	python ./convert23andme/test_convert23andme.py

test: test-convert23andme
