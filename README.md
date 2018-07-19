# Bioinformatics

This repository contains all software that requires knowledge of
bioinformatics software, databases, and methods. The goal is to
sequester the more detailed bioinformatic data handling in this repo,
so that other code repos can simply use this repo as a black box.


## Requirements

Docker must be installed and available.


## Installation

An easy mnemonic: run the various `docker-*` scripts in alphabetical order!

First, build the Docker image. The `docker-build.sh` script takes four parameters: mode, target image tag, and AWS profile (from `~/.aws/credentials`). Mode is either `link` or `build`. `link` is for development mode, and mounts a volume from the host to connect to the `/precisely/app` directory in the container.

```
./docker-build.sh link bio1-img dev-profile-precisely
```

Second, create a container. The `docker-create.sh` script takes three or four parameters: mode, image tag, container name, and (in link mode only) the application source path.

```
./docker-create.sh link bio1-img bio1 .
```

Third, start the container.

```
./docker-start.sh bio1
```

In development (link) mode, you can now connect to the container and use it:

```
./docker-tmux.sh bio1
```


## Running

The `run.sh` script is the entry point. It takes two parameters: an input 23andMe genome file, and a sample ID (an arbitrary string).

Right now, it's hard-coded to run a simplified (only chromosome 21) imputation pass and produce some output files. Please read it to understand what it does, it's fairly short and straightforward.


## Reference information

### 23andMe's tab-delimited raw data format

- 23andMe's data format documentation: https://customercare.23andme.com/hc/en-us/articles/115004459928-Raw-Data-Technical-Details
- http://fileformats.archiveteam.org/wiki/23andMe


### Obtaining 23andMe example data files for testing

- Source of publicly-available 23andMe datasets for testing: https://my.pgp-hms.org/public_genetic_data?data_type=23andMe


### Building the Compressed Reference Human Genome for bcftools

- Obtain the 1k Genomes reference human genome


### Building the Gene Coordinates BED File

- This is checked in as:
  convert23andme/ucsc-gene-symbols-coords.txt.gz
- This will only need to be updated if we need to support a human
  genome build other than 37.
- BED file obtained from the UCSC Genome Browser (see below)
- Idea of how to annotate the variants with gene names from here: https://www.biostars.org/p/122690/
- In the future, this should be automated using the cruzdb Python package


#### Generating the Gene Coordinate BED file using the UCSC Genome Browser

Go to UCSC Genome Browser page: https://genome.ucsc.edu/cgi-bin/hgTables

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

Post-processing of the BED file:

```
$ awk -F'\t' 'BEGIN{ OFS="\t"} \
NR!=1 { gsub("chr","",$2); if($2 == "M") $2 = "MT"; print $2, $4, $5, $7  }' \
ucsc-gene-names.txt \
| sort -k1,1 -k2,2n \
| bgzip > ucsc-gene-symbols-coords.txt.gz
```

Use Tabix to index the BGzip'ed file:

```
$ tabix -p bed ucsc-gene-symbols-coords.txt.gz
```


### Backgroup VCF File Manipulation Documentation

- BCFtools documentation: https://samtools.github.io/bcftools/bcftools.html
- Using BCFtools to convert 23andMe to VCF: https://samtools.github.io/bcftools/howtos/convert.html
- Example using BCFtools to annotate variants with gene information: https://www.biostars.org/p/122690/
- Docs for PySam: http://pysam.readthedocs.io/en/stable/usage.html#working-with-vcf-bcf-formatted-files
