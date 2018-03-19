#!/bin/bash

container="$1"
data23andme_file="$2"

docker 
docker run -d "$container"

cp $data23andme_file $PWD

docker exec -d "$container" python convert23andme/convert23andme.py \
       "/shared/`basename $data23andme_file`" \
       data/human_g1k_v37.fasta.gz \
       convert23andme/ucsc-gene-symbols-coords.txt.gz \
       /shared

