## TODOs:
## * use named pipe instead of intermediate BCF file.
## * In a future version, we need to dispatch on file metadata to
##   automagically select the correct version of the reference genome.
##   See get_genome_version for where the logic needs to be inserted,
##   and definition of cruzdb.


### Import statements:
from pysam import VariantFile
import subprocess, sys, json
from time import time
from cruzdb import Genome


### Global Definitions:

## Hash that maps genome version and chromosome ID to NCBI Accession number:
human_genome_accessions = {
    'GRCh37': {
        '1':  'NC_000001.10',
        '2':  'NC_000002.11',
        '3':  'NC_000003.11',
        '4':  'NC_000004.11',
        '5':  'NC_000005.9',
        '6':  'NC_000006.11',
        '7':  'NC_000007.13',
        '8':  'NC_000008.10',
        '9':  'NC_000009.11',
        '10': 'NC_000010.10',
        '11': 'NC_000011.9',
        '12': 'NC_000012.11',
        '13': 'NC_000013.10',
        '14': 'NC_000014.8',
        '15': 'NC_000015.9',
        '16': 'NC_000016.9',
        '17': 'NC_000017.10',
        '18': 'NC_000018.9',
        '19': 'NC_000019.9',
        '20': 'NC_000020.10',
        '21': 'NC_000021.8',
        '22': 'NC_000022.10',
        'X':  'NC_000023.10',
        'Y':  'NC_000024.9',
        'MT': 'NC_012920.1'
        }
    }


    
def convert_23andme_bcf(genotype_23andme_path,
                            ref_human_genome_path,
                            annotate_file_path,
                            ga4gh_out_dir):
    
    ## Definitions:    
    [sample_id, file_md5_hash_value] = genotype_23andme_path.split('/')[-1].split('_')
    temp_bcf_file = '/tmp/' + sample_id + '.bcf'
    
    ## Command for using bcftools for converting 23&Me tab-delimited
    ## genotype files to VCF format:
    
    # subprocess.check_output([
    #     'bcftools',
    #     'convert',
    #     '--tsv2vcf',
    #     genotype_23andme_path,
    #     '-f',
    #     ref_human_genome_path,
    #     '-s',
    #     sample_id,
    #     '-Ob',
    #     '-o',
    #     temp_bcf_file])

    with open('/tmp/header-file.txt','w') as header_file:
        print >> header_file, r"##INFO=<ID=GENE,Number=1,Type=String,Description=\"Gene name\">"
        
    subprocess.check_output(' '.join(['bcftools',
                                        'convert',
                                        '--tsv2vcf',
                                        genotype_23andme_path,
                                        '-f',
                                        ref_human_genome_path,
                                        '-s',
                                        sample_id,
                                        '-Ob',
                                        '|',
                                        'bcftools',
                                        'annotate',
                                        '-a',
                                        annotate_file_path,
                                        '-c CHROM,FROM,TO,GENE',
                                        '-h'
                                        '/tmp/header-file.txt',
                                        '-Ob',
                                        '-o',
                                        temp_bcf_file,
                                        '-']),
                                shell=True)

    
    ## Load in variants from BCF file:
    bcf_in = VariantFile(temp_bcf_file)

    json_out_file = ga4gh_out_dir + '/' + sample_id + '_ga4gh.json'

    variants = []
    load_time = time()
    i = 0
    
    with open(json_out_file,'w') as out_file:

        out_file.write('[')
        
        for rec in bcf_in:
            struct = gen_variant_call_struct(rec,
                                                 sample_id,
                                                 load_time)
            if struct != None:
                #variants.append(struct)
                out_file.write(json.dumps(struct, indent=4, separators=(',', ': ')))
                out_file.write(',')
           
        out_file.write(']')
                ##out_file.write(json.dumps(variants, indent=4, separators=(',', ': ')))

    print json_out_file

    

## Generate json stanza:
## If the variant is not within a gene, we discard it.
def gen_variant_call_struct(rec, sample_id, load_time):

    genotype_array = list(rec.samples[sample_id].values()[0])

    genotype = ''
    
    if genotype_array == [None]:
        genotype = 'not-determined'
        genotype_array = [-1, -1]
    elif genotype_array == [0, 0]:
        genotype = 'wildtype'
    elif genotype_array == [0, 1] or genotype_array == [1, 0]:
        genotype = 'heterozygous'
    elif genotype_array == [1, 1]:
        genotype = 'homozygous'
    elif genotype_array == [1, 2] or genotype_array == [2, 1]:
        genotype = 'compound-heterozygous'
    elif rec.chrom in [ 'Y', 'MT', 'X' ] and genotype_array in [ [0], [1] ]:
        genotype = 'haploid'        
    else:
        print rec.id, rec.chrom, genotype, genotype_array, rec.samples[sample_id].values()
        raise
    
    genome_version = get_genome_version()

    gene = ''
    if 'GENE' in rec.info:
        gene = rec.info['GENE']

    alt_bases = ''
    
    if rec.alts == None:
        alt_bases = '<NON_REF>'
    else:
        alt_bases = list(rec.alts)

    if genotype != 'not-determined':
        svn_str = gen_svn_genotype_string(get_genome_version(),
                                            rec.chrom,
                                            rec.pos,
                                            rec.ref,
                                            alt_bases,
                                            genotype)
        filter_val = 'PASS'
    else:
        svn_str = ''
        filter_val = 'NOT-DETERMINED'
    
    if gene == '':
        return None
    else:
        return {
            'alternateBases': alt_bases,
            'calls': [{
                'callSetId': sample_id,
                'genotype': genotype_array,
                'info': { 'FILTER': [ filter_val ] }
            }],
            'end': rec.stop,
            'referenceBases': rec.ref,
            'referenceName': 'chr' + rec.chrom,
            'start': rec.start,
            'attributes': {
                'sample': {
                    'load_time': load_time,
                    'reference_version': genome_version
                    },
                    'variant': {
                        'gene_symbols': gene,
                        'id': rec.id
                        },
                        'variant_call': {
                            'genotype': genotype,
                            'systematic_name': svn_str
                            }}}


    
    
## Generate a Sequence Variant Nomenclature-based description of the genotype:        
def gen_svn_genotype_string(genome_version,
                        chrom,
                        start,
                        ref,
                        alt_bases,
                        zygosity):

    
    accession = human_genome_accessions[genome_version][chrom]

    svn_str = accession + ':g.' 
    print_sub_template = '[{}{}>{}]'
    print_wildtype_template = '[{}=]'
    
    if zygosity == 'wildtype':
        svn_str = svn_str + \
          print_wildtype_template.format(start) + \
          ';' + \
          print_wildtype_template.format(start)
                                           
    elif len(alt_bases) == 1 and zygosity == 'heterozygous':
        svn_str = svn_str + \
          print_wildtype_template.format(start) + \
          ';' + \
          print_sub_template.format(start,
                                        ref,
                                        alt_bases[0])

    elif len(alt_bases) == 1 and zygosity == 'homozygous':
        svn_str = svn_str + \
          print_sub_template.format(start,
                                        ref,
                                        alt_bases[0]) + \
          ';' + \
          print_sub_template.format(start,
                                        ref,
                                        alt_bases[0])


    elif len(alt_bases) == 2:
        svn_str = svn_str + \
          print_sub_template.format(start,
                                        ref,
                                        alt_bases[0]) + \
          ';' + \
          print_sub_template.format(start,
                                        ref,
                                        alt_bases[1])

    elif zygosity == 'haploid' and alt_bases != '<NON_REF>':
        svn_str = svn_str + \
          print_sub_template.format(start,
                                        ref,
                                        alt_bases[0])

    elif zygosity == 'haploid' and alt_bases == '<NON_REF>':
        svn_str = svn_str + \
          print_wildtype_template.format(start)

        
    return svn_str


def get_snp_gene_names(chrom, pos):

    if chrom == 'MT':
        chrom = 'M'

    chrom_str = 'chr' + chrom
        
    genes = cruzdb.bin_query('refGene', chrom_str, pos, pos)

    return list(set([g.name2 for g in genes]))


### This needs to dispatch based on the headers of the 23&Me data
### files. Static for now:
def get_genome_version():
    return 'GRCh37'

## CruzDB object for obtaining gene names:
## This needs to dispatch based on the genome version,
## currently just supporting GRCh37/hg19:
if get_genome_version() == 'GRCh37':
    cruzdb = Genome('hg19')


## Obtain variable definitions from the environment:
genotype_23andme_path = sys.argv[1]
ref_human_genome_path = sys.argv[2]
annotate_file_path    = sys.argv[3]
ga4gh_out_dir         = sys.argv[4]

convert_23andme_bcf(genotype_23andme_path,
                            ref_human_genome_path,
                            annotate_file_path,
                            ga4gh_out_dir)

