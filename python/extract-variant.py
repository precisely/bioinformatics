#!/usr/bin/env python


from __future__ import print_function
import json
import os
import os.path
import sys

import pysam


### parameters
if len(sys.argv) != 3:
    print("usage: extract-variant.py <variants-json-file> <imputed-chromosomes-path>", file=sys.stderr)
    sys.exit(1)

variant_reqs_filename = sys.argv[1]
if not os.path.isfile(variant_reqs_filename):
    print("{} not found".format(variant_reqs_filename), file=sys.stderr)
    sys.exit(1)

imputed_chromosomes_path = sys.argv[2]
if not os.path.isdir(imputed_chromosomes_path):
    print("{} not found".format(imputed_chromosomes_path), file=sys.stderr)
    sys.exit(1)

expected_imputed_files = set([
    "chr1.vcf.bgz", "chr1.vcf.bgz.tbi", "chr2.vcf.bgz", "chr2.vcf.bgz.tbi",
    "chr3.vcf.bgz", "chr3.vcf.bgz.tbi", "chr4.vcf.bgz", "chr4.vcf.bgz.tbi",
    "chr5.vcf.bgz", "chr5.vcf.bgz.tbi", "chr6.vcf.bgz", "chr6.vcf.bgz.tbi",
    "chr7.vcf.bgz", "chr7.vcf.bgz.tbi", "chr8.vcf.bgz", "chr8.vcf.bgz.tbi",
    "chr9.vcf.bgz", "chr9.vcf.bgz.tbi", "chr10.vcf.bgz", "chr10.vcf.bgz.tbi",
    "chr11.vcf.bgz", "chr11.vcf.bgz.tbi", "chr12.vcf.bgz", "chr12.vcf.bgz.tbi",
    "chr13.vcf.bgz", "chr13.vcf.bgz.tbi", "chr14.vcf.bgz", "chr14.vcf.bgz.tbi",
    "chr15.vcf.bgz", "chr15.vcf.bgz.tbi", "chr16.vcf.bgz", "chr16.vcf.bgz.tbi",
    "chr17.vcf.bgz", "chr17.vcf.bgz.tbi", "chr18.vcf.bgz", "chr18.vcf.bgz.tbi",
    "chr19.vcf.bgz", "chr19.vcf.bgz.tbi", "chr20.vcf.bgz", "chr20.vcf.bgz.tbi",
    "chr21.vcf.bgz", "chr21.vcf.bgz.tbi", "chr22.vcf.bgz", "chr22.vcf.bgz.tbi",
    "chrX.vcf.bgz", "chrX.vcf.bgz.tbi", "chrY.vcf.bgz", "chrY.vcf.bgz.tbi",
    "chrMT.vcf.bgz", "chrMT.vcf.bgz.tbi"])
found_imputed_files = set(os.listdir(imputed_chromosomes_path))
if expected_imputed_files != found_imputed_files:
    print("{} does not seem to contain imputed genotype files".format(imputed_chromosomes_path), file=sys.stderr)
    sys.exit(1)


### helper functions
def read_genotypes(row):
    formats = row.format.split(":")
    data_encoded = row[0].split(":")
    data = dict(zip(formats, data_encoded))
    return [int(g) for g in data["GT"].split("|")]


### run
# TODO: This should use a streaming JSON parser instead of reading the entire file
# into memory.
with open(variant_reqs_filename) as f:
    variant_reqs = json.load(f)

reqs_by_file = {}

for req in variant_reqs:
    if req["refVersion"] != "37p13":
        print("variant for {} has version {} instead of 37p13".format(req["id"], req["refVersion"]), file=sys.stderr)
        sys.exit(1)
    chr = req["refName"]
    if req["refName"] in reqs_by_file:
        reqs_by_file[req["refName"]].add(req["start"])
    else:
        reqs_by_file[req["refName"]] = set([req["start"]])

res = []

for ref, starts in reqs_by_file.iteritems():
    f = os.path.join(imputed_chromosomes_path, "{}.vcf.bgz".format(ref))
    #vcf = pysam.VariantFile(f)
    #sample_id = vcf.header.samples[0]
    idx = pysam.TabixFile(f)
    chromosome = ref.replace("chr", "")
    for start in starts:
        for row in idx.fetch(chromosome, start-1, start, parser=pysam.asVCF()):
            # TODO: Include genotypeLikelihood; it parses like read_genotypes
            # but uses "GP" key.
            res.append({
                "refVersion": "37p13",
                "refName": ref,
                "start": start,
                "altBases": list(row.alt),
                "refBases": row.ref,
                # TODO: Get "filter" working; it does not validate with "PASS". Also, why must it be an array?
                #"filter": [row.filter],
                "genotype": read_genotypes(row)
            })

print(json.dumps(res))
