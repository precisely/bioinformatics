#!/bin/bash
#SBATCH -p skylake                                         # partition
#SBATCH -N 1                                             # number of nodes
#SBATCH -n 4                                             # number of cores
#SBATCH --time=30:00:00                                  # time allocation
#SBATCH --mem=32GB 										 # memory
#SBATCH --array=1
#SBATCH -o /fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Align_Call_2019_Aug/Slurm/Out/%x_%A_%a.out		
#SBATCH -e /fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Align_Call_2019_Aug/Slurm/Out/%x_%A_%a.err
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=rick.tearle@adelaide.edu.au

## Genotype GVCF files ##

echo "#############################"
echo -e "Genotype_GVCFs_GATK4-Slurm.sh"
date
TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS

# Modules
MODULES=( SAMtools/1.8-foss-2016b 
          GATK/4.0.0.0-Java-1.8.0_121 
          BCFtools/1.6-foss-2016b 
          VCFtools/0.1.14-GCC-5.3.0-binutils-2.25-Perl-5.22.0 )

for MODULE in ${MODULES[@]}; do
	module load $MODULE
	RESULT=$?
	if [ $RESULT -ne 0 ]; then
		echo -e "\nCould not load $MODULE\n"
		echo $RESULT
		exit $RESULT
	else
		echo -e "Loading module $MODULE"
	fi
done

echo ""

# Variables
DIR_IN='/fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Out/Alignments/GRCh38'
DIR_OUT='/fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Out/Alignments/GRCh38'
GVCF_IN='NA12878_10_1x-vs-GRCh38.g.vcf.gz'
VCF_OUT='NA12878_10_1x-vs-GRCh38.vcf.gz'

REF_SUFFIX='/fast/users/a1222182/Genomes/Human_Genome/GRCh38/BWA/Homo_sapiens.GRCh38.dna.primary_assembly'
REF=${REF_SUFFIX}'.fa'

echo ""
echo "DIR_IN: $DIR_IN}"
echo "DIR_OUT: ${DIR_OUT}"
echo "GVCF_IN: ${GVCF_IN}"
echo "VCF_OUT: ${VCF_OUT}"
echo ""
echo "REF: ${REF}"
echo "REF_SUFFIX: ${REF_SUFFIX}"
echo ""

FOUND=0

i=0
FOUND=1

if [ "${FOUND}" -eq 1 ]; then
  
  echo "i: ${i}"

  if [[ ! -e "${DIR_OUT}" ]]; then 
    mkdir -p $DIR_OUT
  
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
      echo "Cannot create dir $DIR_OUT" 
      echo $RESULT
      exit $RESULT
    fi
  fi

  echo -e "Running GenotypeGVCFs"
  date
  TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS
  
  # Build command   
  
  
  "gatk GenotypeGVCFs \\
    -nt 4 \\
    -R ${REF} \\
    -V  ${DIR_IN}/${GVCF_IN} \\
    -O  ${DIR_OUT}/${VCF_OUT}
    "
 	
  gatk GenotypeGVCFs \
    -nt 4 \
    -R ${REF} \
    -V  ${DIR_IN}/${GVCF_IN} \
    -O  ${DIR_OUT}/${VCF_OUT}
    
  RESULT=$?
  if [ $RESULT -ne 0 ]; then
    echo -e "\nCannot run GenotypeGVCFs\n"
    echo $RESULT
    exit $RESULT
  fi
  
  echo -e "\nCompleted\n"
  
  date
  TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS
  
fi  




