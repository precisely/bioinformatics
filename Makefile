## I forget whether the version that you download is GZip'ed or BGzip'ed.
## Might be necessary to decompress and recompress using bgzip.
build-human-genome-ref-db:
	cd /tmp
	wget ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/technical/reference/human_g1k_v37.fasta.gz

