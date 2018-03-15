- Source of publicly-available 23&Me datasets for testing: https://my.pgp-hms.org/public_genetic_data?data_type=23andMe
- 23&Me's data format documentation: https://customercare.23andme.com/hc/en-us/articles/115004459928-Raw-Data-Technical-Details
- http://fileformats.archiveteam.org/wiki/23andMe
- Obtain the 1k Genomes reference human genome:
- wget ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/technical/reference/human_g1k_v37.fasta.gz
- wget ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/technical/reference/human_g1k_v37.fasta.fai
- BED file obtained from https://genome.ucsc.edu/cgi-bin/hgTables
- Using UCSC gene list, and selecting fields from primary and secondary tables, including the 'Gene Symbol' field.
- Idea of how to append the gene names from here: https://www.biostars.org/p/122690/
- Making the annotation file:
- precisely@consulting-vb:~/data$ awk -F'\t' 'BEGIN{ OFS="\t"} NR!=1 { gsub("chr","",$2); if($2 == "M") $2 = "MT"; print $2, $4, $5, $7  }' ucsc-gene-names.txt | sort -k1,1 -k2,2n | bgzip > ucsc-gene-symbols-coords.txt.gz
- precisely@consulting-vb:~/data$ tabix -p bed ucsc-gene-symbols-coords.txt.gz 
- BCFtools documentation: https://samtools.github.io/bcftools/bcftools.html
- Using BCFtools to convert 23&Me to VCF: https://samtools.github.io/bcftools/howtos/convert.html
- Example using BCFtools to annotate variants with gene information: https://www.biostars.org/p/122690/
- Depends on PySam: http://pysam.readthedocs.io/en/stable/usage.html#working-with-vcf-bcf-formatted-files

## Generating the Gene Coordinate BED file for BCFtools:

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

Once downloaded, remove the first comment line from the file.

Then, compress using bgzip.
Then, index using tabix:


