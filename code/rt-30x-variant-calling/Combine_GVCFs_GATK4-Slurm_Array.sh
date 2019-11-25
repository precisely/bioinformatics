#!/bin/bash
#SBATCH -p batch                                         # partition
#SBATCH -N 1                                             # number of nodes
#SBATCH -n 2                                             # number of cores
#SBATCH --time=04:00:00                                  # time allocation
#SBATCH --mem=16GB 										 # memory
#SBATCH --array=1
#SBATCH -o /fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Align_Call_2019_Aug/Slurm/Out/%x_%A_%a.out		
#SBATCH -e /fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Align_Call_2019_Aug/Slurm/Out/%x_%A_%a.err
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=rick.tearle@adelaide.edu.au

## Bash script to run fastqc on contents of a dir ##

echo "#############################"
echo -e "Combine_GVCFs_GATK4-Slurm_Array.sh"
date
TZ=UTC0 printf '%(%H:%M:%S)T\n\n' ${SECONDS}

# Modules
MODULES=( SAMtools/1.8-foss-2016b 
          GATK/4.0.0.0-Java-1.8.0_121 
          BCFtools/1.6-foss-2016b 
          freebayes/1.0.2-GCC-4.9.3-binutils-2.25 
          VCFtools/0.1.14-GCC-5.3.0-binutils-2.25-Perl-5.22.0 )

for MODULE in ${MODULES[@]}; do
	module load $MODULE
	RESULT=$?
	if [ $RESULT -ne 0 ]; then
		echo -e "\nCould not load $MODULE\n"
		echo $RESULT
		#exit $RESULT
	else
		echo -e "Loading module $MODULE"
	fi
done

echo ""

# Variables
DIR_IN='/fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Out/Alignments/GRCh38'
DIR_OUT='/fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Out/Alignments/GRCh38'
FILE_PREFIX='-vs-GRCh38'
GVCF_ALL='NA12878_10_1x'${FILE_PREFIX}'.g.vcf.gz'

SAMPLE_IDS=( NA12978-0
             NA12978-1
             NA12978-2
             NA12978-3
             NA12978-4
             NA12978-5
             NA12978-6
             NA12978-7
             NA12978-8
             NA12978-9 )

REF_SUFFIX='/fast/users/a1222182/Genomes/Human_Genome/GRCh38/BWA/Homo_sapiens.GRCh38.dna.primary_assembly'
REF=${REF_SUFFIX}'.fa'
# SNPS='/fast/users/a1222182/Genomes/Bovine_Genome/ARS-UCD1.2_Btau5.0.1Y/ARS1.2PlusY_BQSR.vcf.gz'


if [[ ! -e "${DIR_OUT}" ]]; then 
  mkdir -p ${DIR_OUT}

  RESULT=$?
  if [ "${RESULT}" -ne 0 ]; then
    echo "Cannot create dir ${DIR_OUT}" 
    echo ${RESULT}
    exit ${RESULT}
  fi
fi

echo "DIR_IN: ${DIR_IN}"
echo "DIR_OUT: ${DIR_OUT}"
echo "FILE_PREFIX: ${FILE_PREFIX}"
echo "GVCF_ALL: ${GVCF_ALL}"
echo ""
echo "SAMPLE_IDS: ${SAMPLE_IDS[@]}"
echo ""
echo "REF: ${REF}"
echo "REF_SUFFIX: ${REF_SUFFIX}"
echo "SNPS: ${SNPS}"
echo ""

# FOUND=0
# 
# # Assign job id
# FOUND=0
# for (( i=0; i<${NR_SAMPLES}; i++ )); do
# 
# 	j=$((i + 1)) # one offset for task id matching
# 
#  	if [ "$j" -eq "${SLURM_ARRAY_TASK_ID}" ]; then
# 		FOUND=1
# 		break
# 	fi
# 	
# done
# 
# echo "FOUND: ${FOUND}"

i=0
FOUND=1

if [ "${FOUND}" -eq 1 ]; then

  echo "i: ${i}"
  echo "j: ${j}"
  
  echo -e "Running CombineGVCFs"
  date
  TZ=UTC0 printf '%(%H:%M:%S)T\n\n' ${SECONDS}
  
  # Build command
  STRING="gatk CombineGVCFs "'\\'
  COMMAND=${STRING}

  STRING="-R ${REF} "'\\'
  COMMAND=${COMMAND}"\n"${STRING}

#   STRING="-D  ${SNPS} "'\\'
#   COMMAND=${COMMAND}"\n"${STRING}

  for SAMPLE_ID in ${SAMPLE_IDS[@]}; do
    STRING="-V  ${DIR_IN}/${SAMPLE_ID}${FILE_PREFIX}/${SAMPLE_ID}${FILE_PREFIX}.g.vcf.gz "'\\'
    COMMAND=${COMMAND}"\n"${STRING}
  done

  STRING="-O  ${DIR_OUT}/${GVCF_ALL} "
  COMMAND=${COMMAND}"\n"${STRING}

  echo -e ${COMMAND}

  # Clean up command and run
  COMMAND2=$(echo -e ${COMMAND} | sed 's/\\//g')
  
  ${COMMAND2}
 	
  RESULT=$?
  if [ "${RESULT}" -ne 0 ]; then
    echo -e "\nCannot combine GVCFs\n"
    echo ${RESULT}
    exit ${RESULT}
  fi
  
  echo -e "\nCompleted\n"
  
  date
  TZ=UTC0 printf '%(%H:%M:%S)T\n\n' ${SECONDS}
  
fi  






