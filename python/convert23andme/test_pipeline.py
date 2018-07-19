import convert23andme, subprocess
from sys import argv

for file in argv[1:]:
    print "Testing sample: " + file
    convert23andme.convertImpute23andMe2VCF(file,
                                            'ref-data/human_g1k_v37.fasta.bgz',
                                            'convert23andme/ucsc-gene-symbols-coords.txt.gz',
                                            '/tmp',
                                            'testuser1',
                                            debug=True)

