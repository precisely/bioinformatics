# Bioinformatics

This repository contains all software that requires knowledge of
bioinformatics software, databases, and methods. The goal is to
sequester the more detailed bioinformatic data handling in this repo,
so that other code repos can simply use this repo as a black box.

## Installation

To get started, you clone the repo, checkout the correct feature branch, build the project, and then build the docker image:

```
git clone git@github.com:precisely/bioinformatics.git
git checkout taltman/vcf2dydb
make install
make build-docker-image
```

Within the docker image, you need to set up the AWS environment with IAM user credentials (not automated yet).

Then, you can run the test pipeline as follows

```
make test-pipeline
```


### Building a Docker image

* TODO: figure out how to inject AWS IAM credentials into the Docker image

## Converting 23andMe data to Precise.ly-formatted VCF

The convert23andme python module in this repository is for converting
23andMe raw data files into a version of VCF that is tailored to our
needs here at Precise.ly. The module can be used both as a module and
as a script, executing from the command-line as follows:

```
precisely@consulting-vb:~/repos/bioinformatics/convert23andme$ time python \
    ./convert23andme.py \
	~/Downloads/shorttest_deadbeef.txt \
	~/data/human_g1k_v37.fasta.gz \
	~/data/ucsc-gene-symbols-coords.txt.gz ~/tmp
```

### 23andMe's tab-delimited raw data format

- 23&Me's data format documentation: 

	https://customercare.23andme.com/hc/en-us/articles/115004459928-Raw-Data-Technical-Details

- http://fileformats.archiveteam.org/wiki/23andMe


### Obtaining 23andMe example data files for testing

- Source of publicly-available 23&Me datasets for testing: 
  
  https://my.pgp-hms.org/public_genetic_data?data_type=23andMe


### Building the Compressed Reference Human Genome for bcftools

- Obtain the 1k Genomes reference human genome:

	See target `build-human-genome-ref-db` in Makefile.

### Building the Gene Coordinates BED File
- This is checked in as:
  convert23andme/ucsc-gene-symbols-coords.txt.gz
- This will only need to be updated if we need to support a human
  genome build other than 37.
- BED file obtained from the UCSC Genome Browser (see below)
- Idea of how to annotate the variants with gene names from here: 

	https://www.biostars.org/p/122690/
- In the future, this should be automated using the cruzdb Python package

#### Generating the Gene Coordinate BED file using the UCSC Genome Browser

Go to UCSC Genome Browser page:
https://genome.ucsc.edu/cgi-bin/hgTables

Select the following form options:
- clade: Mammal
- genome: Human
- assembly: "Feb. 2009 (GRCh37/hg19)"
- group: "Genes and Gene Predictions"
- track: "UCSC Genes"
- output format: "selected fields from primary and related tables

Leave everything blank or default.

Click on "get output"

On the following page, you will get a chance to select specific
columns from the hg19.knownGene and hg19.kgXref tables. Select the
following:
kg19.knownGene:
- name
- chrom
- txStart
- txEnd

hg19.kgXref:
- geneSymbol

Click on "get output" button below the hg19.knownGene listing.

Once downloaded, remove the first comment line from the file, and call
the file `ucsc-gene-names.txt`.

#### Final processing of BED File
- Post-processing of the BED file:

```
precisely@consulting-vb:~/data$ awk -F'\t' 'BEGIN{ OFS="\t"} \
NR!=1 { gsub("chr","",$2); if($2 == "M") $2 = "MT"; print $2, $4, $5, $7  }' \
ucsc-gene-names.txt \
| sort -k1,1 -k2,2n \
| bgzip > ucsc-gene-symbols-coords.txt.gz
```

- Use Tabix to index the BGzip'ed file:

	`precisely@consulting-vb:~/data$ tabix -p bed ucsc-gene-symbols-coords.txt.gz`

### Backgroup VCF File Manipulation Documentation 

- BCFtools documentation: 

	https://samtools.github.io/bcftools/bcftools.html

- Using BCFtools to convert 23&Me to VCF: 

	https://samtools.github.io/bcftools/howtos/convert.html

- Example using BCFtools to annotate variants with gene information: 
  
  https://www.biostars.org/p/122690/
  
- Docs for PySam: 

	http://pysam.readthedocs.io/en/stable/usage.html#working-with-vcf-bcf-formatted-files

### Docker image for convert23andMe

Here's how to fetch the convert23andme docker image: 
`docker pull taltman/precisely-bioinformatics:ver2`

And here is an example of running the docker image:

`docker run -it -v $HOME:/host_dir dev/precisely-bioinformatics .`

And how to call the script from within the container:
`time python convert23andme/convert23andme.py /host_dir/Downloads/shorttest_deadbeef.txt data/human_g1k_v37.fasta.gz convert23andme/ucsc-gene-symbols-coords.txt.gz /host_dir/tmp`

So in this example, we're mapping the $HOME dir to the /host_dir
directory within the container, and that is where the input file is
referenced on the host file system, and the output file is generated
in that directory.

