import convert23andme, subprocess

convert23andme.convertImpute23andMe2VCF('test/ref/example-chr21-23andme_deadbeef.txt',
                                       'ref-data/human_g1k_v37.fasta.bgz',
                                       'convert23andme/ucsc-gene-symbols-coords.txt.gz',
                                       '/tmp')

