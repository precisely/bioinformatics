'''
convert23andme: Python module for converting 23andMe raw data to VCF format

Provided a 23andMe data file as input, along with a
specially-formatted human genome sequence file and a human genome gene
coordinates file, this module will convert the data into a
Precise.ly-formatted VCF file. See the README for more information on
obtaining the human genome sequence and gene coordinate files.

TODOs:
* In a future version, we need to dispatch on file metadata to
  automagically select the correct version of the reference genome.
* Current text file to VCF conversion does not support indels. This
  would need to be added manually.

## Functions removed:
After tag v0.1, I removed the following functions that were no longer needed:
* gen_svn_genotype_string
* gen_variant_call_struct
* gen_genotype_summary_str
* print_vcf_to_ga4gh_json_file
* predict_23andMe_chip_version
* agumented_vcf_record

'''


### Import statements:
from pysam import VariantFile
import subprocess, sys, json, shutil, os
from time import time
from datetime import datetime
import tempfile, gzip, logging, traceback, boto3


### Global Definitions:

## Hash that maps genome version and chromosome ID to NCBI Accession number:
human_genome_accessions = {
    '37': {
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

    
def parse_23andMe_file(genotype_23andme_path):
    '''Parse out the creation date and the genome assembly version
    from a 23andMe raw data file, and the number of SNPs, and return as a list.'''

    snp_counts = 0
    genome_verison = ''
    
    with open(genotype_23andme_path) as file_23andMe:

        for line in file_23andMe:

            if line.startswith('# This data file generated by 23andMe at:'):
                timestamp_str = line.rstrip().split(': ')[1]
                datetime_object = datetime.strptime(timestamp_str, '%c')
            
            if line.startswith('# More information on reference human assembly build'):
                genome_version = line.rstrip().split('build ')[1].split(' ')[0]
            
            if not line.startswith('#'):
                snp_counts += 1                
                
    return [datetime_object, genome_version, snp_counts]



def convertImpute23andMe2VCF(genotype_23andme_path,
                                ref_human_genome_path,
                                annotate_file_path,
                                output_dir,
                                user_id,
                                debug=False):

    ## Definitions:    
    [sample_id, file_md5_hash_value] = genotype_23andme_path.split('/')[-1].split('_')

    tmp_dir = tempfile.mkdtemp()

    logging.info("Working directory is : " + tmp_dir)

    converted_vcf_file   = tmp_dir + '/' + sample_id + '.vcf.gz'

    imputed_vcf_file     = tmp_dir + '/' + sample_id + '-imputed.vcf.gz'

    imputed_vcf_bgz_file = tmp_dir + '/' + sample_id + '-imputed.vcf.bgz'

    annotated_vcf_file   = tmp_dir + '/' + sample_id + '-gene-annot.vcf.gz'

    final_vcf_file       = tmp_dir + '/' + sample_id + '-final.vcf.gz'
    
    final_vcf_bgz_file   = tmp_dir + '/' + sample_id + '-final.vcf.bgz'

    ## Get 23andMe raw file stats:
    [ processing_datetime,
          genome_version,
          snp_count        ] = parse_23andMe_file(genotype_23andme_path)

    ## Convert 23 & Me text file to VCF format:
    convert_23andme_vcf(genotype_23andme_path,
                            sample_id,
                            ref_human_genome_path,
                            converted_vcf_file)


    ## Impute the VCF file:
    subprocess.check_output(['beagle-leash',
                                 converted_vcf_file,
                                 imputed_vcf_file],
                                 stderr=subprocess.STDOUT)
    
    
    print "foo"
    ## Index the VCF file:
    print
    ## Passing the arguments as a list of strings will not work.
    ## First joining the arguments into one string bypassed the errors.
    ## This is because the list form doesn't support pipelines, see subprocess.Popen docs.
    subprocess.check_output(' '.join(['zcat',
                                          imputed_vcf_file,
                                          '|',
                                          'bgzip',                         
                                          '>',
                                          imputed_vcf_bgz_file]),
                                stderr=subprocess.STDOUT,
                                shell=True)
    
    print "bar"
    subprocess.check_output(['tabix',
                            '-p',
                            'vcf',
                            imputed_vcf_bgz_file],
                            stderr=subprocess.STDOUT)
    
    print "baz"
    ## Annotate the variants with Gene information,
    ## and add custom header fields:
    annotateVCFwithGenes(imputed_vcf_bgz_file,
                             annotated_vcf_file,
                             final_vcf_file,
                             annotate_file_path,
                             ref_human_genome_path,
                             sample_id,
                             processing_datetime,
                             genome_version,
                             snp_count,
                             tmp_dir)
    print "quux"

    ## Need to marshall data into BGzip format again:
    subprocess.check_output(' '.join(['zcat',
                                          final_vcf_file,
                                          '|',
                                          'bgzip',                         
                                          '>',
                                          final_vcf_bgz_file]),
                            stderr=subprocess.STDOUT,
                            shell=True)
    
    vcf2dynamoDB(final_vcf_bgz_file,
                     annotate_file_path,
                     user_id,
                     sample_id,
                     genome_version,
                     debug=debug)
                     
    
    ## Clean-Up
    
    # logging.info('Trying to remove same file from output directory, if it is already there from a previous run.')
    # try:
    #     os.remove(output_dir + '/' + vcf_aug_base_file_name)
    # except OSError:
    #     pass

    logging.info('Moving output from temp directory to output directory.')
    shutil.move(final_vcf_file, output_dir)
    logging.info('Deleting temp directory.')
    shutil.rmtree(tmp_dir)

    return


    
    
    
def convert_23andme_vcf(genotype_23andme_path,
                            sample_id,
                            ref_human_genome_path,
                            converted_vcf_file):
    '''
    Main function for converting 23andMe raw data file into a VCF
    file. Returns a string path to the output file location.

    TODO: The current work-flow does not handle insertion/deletion data.
    '''
    
    ## Command for using bcftools for converting 23&Me tab-delimited
    ## genotype files to VCF format:

    subprocess.check_output(' '.join(['bcftools',
                                        'convert',
                                        '--tsv2vcf',
                                        genotype_23andme_path,
                                        '-f',
                                        ref_human_genome_path,
                                        '-s',
                                        sample_id,
                                        '-Oz',
                                        '-o',
                                        converted_vcf_file]),
                                shell=True)
    
    return 

    

def annotateVCFwithGenes(imputed_vcf_file,
                             annotated_vcf_file,
                             final_vcf_file,
                             annotate_file_path,
                             ref_human_genome_path,
                             sample_id,
                             processing_datetime,
                             genome_version,
                             snp_count,
                             tmp_dir):

    ## 
    ## Make header file
    
    with open(tmp_dir + '/header-file.txt','w') as header_file:
        print >> header_file, "##INFO=<ID=GENE,Number=1,Type=String,Description=\"Gene name from UCSC Genome Browser BED file\">"

        ## Apparently bcftools breaks the VCF format spec by mandating header columns.
        ## The error message suggests trying to use tabix to index the VCF file as a work-around.
        
    subprocess.check_output(' '.join(['bcftools',
                                          'annotate',
                                          '-a',
                                          annotate_file_path,
                                          '-c CHROM,FROM,TO,GENE',
                                          '-h',
                                          tmp_dir + '/header-file.txt',
                                          '-Oz',
                                          '-o',
                                          annotated_vcf_file,
                                          imputed_vcf_file]),
                                shell=True)

    ## Re-insert annotations lost via Beagle:
    addHeaderDocs_filterVal2vcfFile(annotated_vcf_file,
                                        final_vcf_file,
                                        tmp_dir,
                                        sample_id,
                                        processing_datetime,
                                        genome_version,
                                        snp_count,
                                        ref_human_genome_path)
    
    return 


def addHeaderDocs_filterVal2vcfFile(vcf_file,
                                        vcf_aug_file,
                                        tmp_dir,
                                        sample_id,
                                        date_23andMe_process,
                                        genome_version,
                                        snp_count,
                                        reference_file_name):
    '''
    This helper function writes out the parsed data into VCF format.
    '''
    
    vcf_in  = VariantFile(vcf_file)

    ## Add additional header lines to the VCF:

    new_header = vcf_in.header
    new_header.add_line('##fileDate='                  + datetime.strftime(datetime.now(), '%c')       )
    new_header.add_line('##23andMeSampleID='           + sample_id                                     )
    new_header.add_line('##23andMeProcessDate='        + datetime.strftime(date_23andMe_process, '%c') )
    new_header.add_line('##23andMeHumanGenomeVersion=' + genome_version                                )
    new_header.add_line('##23andmeSNPcount='           + str(snp_count)                                )
    new_header.add_line('##reference=file://'          + reference_file_name                           )
    new_header.add_line('##FILTER=<ID=NOT_DETERMINED,Description="Genotype not determined by 23andMe">')
    
    ##vcf_out = VariantFile(vcf_aug_file, 'w', header=new_header)

    temp_header_file = tmp_dir + '/header_temp.vcf'

    with open(temp_header_file, 'w') as header_file:
        logging.info('PySAM is buggy, returning an extra space character when printing the header object. Removing.')
        print >> header_file, new_header,

    # vcf_bgz_in  = VariantFile(vcf_file, 'r')
    # vcf_bgz_out = VariantFile(vcf_aug_file, 'w', header=new_header)

    
    # for rec in bcf_in.fetch('chr1', 100000, 200000):
    # bcf_out.write(rec)

    
    with gzip.open(vcf_aug_file, 'w') as vcf_out:
    
        with open(temp_header_file, 'r') as header_file:                      
            for line in header_file:
                if line.startswith('#'):
                    print >> vcf_out, line.rstrip()   

                    
        with gzip.open(vcf_file, 'r') as vcf_in:

            for line in vcf_in:

                if not line.startswith('#'):
                
                    fields = line.rstrip().split('\t')

                    ## Modify FILTER values
                    if fields[9] == '.':                        
                        fields[6] = 'NOT_DETERMINED'
                    else:
                        fields[6] = 'PASS'
                    
                    print >> vcf_out, '\t'.join(fields)


    logging.info('Printed augmented VCF file to: ' + vcf_aug_file)
    return


### Utilities

def vcf2dynamoDB (filename, annotate_file_path, userID, sampleID, genomeVersion, debug=False):
    '''
    A test function for prototyping the bulk upload of VCF file data to DynamoDB.

    TODO:
    * insert accession number instead of chromosome number
    * add gene start & stop annots, not just min & max coords
    * canonicalize [1,0] genotype to [0,1]
    * improve logic about endBase for indels & MNVs
    '''
    
    ## Set up the AWS DynamoDB environment:
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('tomer-variant-call')

    ## Load in the gene transcripts' min and max coordinates:
    gene_min_coord = {}
    gene_max_coord = {}
    
    with gzip.open(annotate_file_path) as geneCoords:
        for coordLine in geneCoords:

            coords = coordLine.rstrip().split('\t')
            idx    = coords[0] + '_' + coords[3]
            
            if idx in gene_min_coord:
                if coords[1] < gene_min_coord[idx]:
                    gene_min_coord[idx] = coords[1]
                if coords[2] > gene_max_coord[idx]:
                    gene_max_coord[idx] = coords[2]                    
            else:
                gene_min_coord[idx] = coords[1]
                gene_max_coord[idx] = coords[2]
    
    
    ## Iterate over the VCF file:

    num_rec = 0
    vcf_in = VariantFile(filename)
    
    with table.batch_writer() as vcf_batch:
        
        for rec in vcf_in.fetch():

            num_rec += 1

            ## Create local variables for boto3,
            ## as doesn't like handling the VariantFile records directly:
            ## This def for endBase will work for SNVs and single MNVs,
            ## But could be more complicated for indels & multiple MNVs of differing lengths...
            
            
            if rec.alts == None:
                currAltBases    = None
                currAltBasesStr = '.'
                currEndBase     = rec.pos
            elif len(rec.alts) == 1:
                currAltBases    = rec.alts[0]
                currAltBasesStr = currAltBases
                currEndBase     = rec.pos + len(currAltBases) - 1
            else:
                ## Dynamo cannot handle tuples, so cast as a list
                ## (this is in the rare case of two alternate alleles at the locus):
                currAltBases    = list(rec.alts)
                currAltBasesStr = ','.join(currAltBases)
                currEndBase     = map(lambda x: currStartBase + len(x) -1, currAltBases)
                
            currChrom     = rec.chrom
            currStartBase = rec.pos            
            currRefBases  = rec.ref
            currFilter    = rec.filter.keys()[0]
            currRsID      = rec.id
        
            if 'GENE' in rec.info:
                currGene     = rec.info['GENE']
                geneMinCoord = gene_min_coord[currChrom + '_' + currGene]
                geneMaxCoord = gene_max_coord[currChrom + '_' + currGene]
            else:
                currGene     = None
                geneMinCoord = None
                geneMaxCoord = None

                
            rec_sample    = rec.samples[rec.samples.keys()[0]]
            currGenotype  = list(rec_sample['GT'])
            
            variantID     = ':'.join([sampleID, genomeVersion, currChrom, str(currStartBase), currRsID, currAltBasesStr])
            ##print variantID
            
            currItem = {
                'userId'             : userID,
                'variantId'          : variantID,
                'chromosomeAccession': currChrom,
                'startBase'          : currStartBase,
                'endBase'            : currEndBase,
                'alternateBases'     : currAltBases,
                'referenceBases'     : currRefBases,
                'filter'             : currFilter,
                'geneSymbol'         : currGene,
                'genotype'           : currGenotype,
                'rsId'               : currRsID,
                'geneMinCoord'       : geneMinCoord,
                'geneMaxCoord'       : geneMaxCoord#,
                #'genotypeLikelihood': rec.GP(),
                }
                
            if debug == True:
                #print rec.samples
                #print rec.samples.keys()
                currItem['debugStatus'] = 'debug'
                #print currItem
                if (num_rec % 50) == 0:
                    print "Processed " + str(num_rec) + " variants."
                
            vcf_batch.put_item(Item=currItem)

    return
            
                    
            
    
        
    
    


## Obtain variable definitions from the environment:
if __name__ == "__main__":
    
    genotype_23andme_path = sys.argv[1]
    ref_human_genome_path = sys.argv[2]
    annotate_file_path    = sys.argv[3]
    output_dir            = sys.argv[4]

    try:
    
        convert_23andme_vcf(genotype_23andme_path,
                                ref_human_genome_path,
                                annotate_file_path,
                                output_dir)

    except:
        ## Trap any errors when running as script, and report the
        ## stack trace:
        [sample_id, file_md5_hash_value] = genotype_23andme_path.split('/')[-1].split('_')

        error_file_path = output_dir + '/' + sample_id + '.error'
        
        with open(error_file_path, 'w') as error_file:
            
            print >> error_file, "Exception type:", sys.exc_info()[0]
            print >> error_file, "Exception Args:", sys.exc_info()[1]
            print >> error_file, traceback.format_exc()

        print error_file_path
        sys.exit(1)
