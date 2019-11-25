#!/bin/bash
#SBATCH -p batch                                         # partition
#SBATCH -N 1                                             # number of nodes
#SBATCH -n 2                                             # number of cores
#SBATCH --time=01:00:00                                  # time allocation
#SBATCH --mem=2GB 										 # memory
#SBATCH --array=23
#SBATCH -o /fast/users/a1222182/Human/NA12878_2019_Aug/2019_Sep/Slurm/Out/%x_%A_%a.out		
#SBATCH -e /fast/users/a1222182/Human/NA12878_2019_Aug/2019_Sep/Slurm/Out/%x_%A_%a.err
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=rick.tearle@adelaide.edu.au

## Bash script to call variants from low coverage data ##
echo "#############################"
echo -e "Call_Low_Coverage_Variants-Slurm_Array.sh"
date
TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS

SLURM_ID=$SLURM_ARRAY_TASK_ID
echo -e "Slurm array ID: $SLURM_ID\n"

source ~/.bashrc
conda init bash
conda activate sequencetools

RESULT=$?
if [ ${RESULT} -gt 0 ]; then 
  echo -e "\nCould not activate conda environment sequencetools \n"
  echo $RESULT
  exit $RESULT
else
  echo -e "\nActivated conda environment sequencetools \n"
fi

echo "Conda environments"
conda info --envs
echo ""

# Modules
MODULES=( SAMtools/1.9-foss-2016b 
          BCFtools/1.9-foss-2016b  
          GATK/4.0.0.0-Java-1.8.0_121 )

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

echo -e "\n"

# Variables
CHRS=( 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 Y )
NR_CHRS=${#CHRS[*]}

SNP_FILE_IN_DIR='/fast/users/a1222182/Human/NA12878_2019_Aug/2019_Sep/In/Autosomes'
SNP_FILE_IN_PREFIX='India_Reference-chr'
SNP_FILE_IN_SUFFIX='_SNPs-GRCh38.tsv'

REF_PREFIX='/fast/users/a1222182/Genomes/Human_Genome/GRCh38/BWA/Homo_sapiens.GRCh38.dna.primary_assembly'
REF=${REF_PREFIX}'.fa'

BAM_DIR_IN='/fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Out/Alignments/GRCh38'
BAM_FILE_IN_SUFFIX='-vs-GRCh38'

SAMPLE_IDS=( NA12978-0 NA12978-1 NA12978-2 NA12978-3 NA12978-4 NA12978-5 NA12978-6 NA12978-7 NA12978-8 NA12978-9 )
NR_SAMPLES=${#SAMPLE_IDS[*]}

DIR_OUT='/fast/users/a1222182/Human/NA12878_2019_Aug/2019_Sep/Out/Autosomes/Chrs'
FILE_OUT_PREFIX='NA12878_10_1x-chr'

if [[ ! -e "${DIR_OUT}" ]]; then 
  mkdir -p $DIR_OUT

  RESULT=$?
  if [ $RESULT -ne 0 ]; then
    echo "Cannot find nor create dir $DIR_OUT" 
    echo $RESULT
    exit $RESULT
  fi
fi

echo "CHRS: ${CHRS[@]}"
echo "NR_CHRS: ${NR_CHRS}"
echo ""
echo "SNP_FILE_IN_DIR: ${SNP_FILE_IN_DIR}"
echo "SNP_FILE_IN_PREFIX: ${SNP_FILE_IN_PREFIX}"
echo "SNP_FILE_IN_SUFFIX: ${SNP_FILE_IN_SUFFIX}"
echo ""
echo "REF: ${REF}"
echo "REF_PREFIX: ${REF_PREFIX}"
echo ""
echo "BAM_DIR_IN: ${BAM_DIR_IN}"
echo "BAM_FILE_IN_SUFFIX: ${BAM_FILE_IN_SUFFIX}"
echo "DIR_OUT: ${DIR_OUT}"
echo "FILE_OUT_PREFIX: ${FILE_OUT_PREFIX}"
echo ""
echo "SAMPLE_IDS: ${SAMPLE_IDS[@]}"
echo "NR_SAMPLES: ${NR_SAMPLES}"
echo ""

# Create seq dict
if [ ! -f ${REF_PREFIX}'.dict' ]; then

  echo "Creating sequence dictionary"
  gatk CreateSequenceDictionary -R ${REF}
  
  RESULT=$?
  if [ $RESULT -ne 0 ]; then
    echo -e "\nCould not create sequence dict for  $REF\n"
  	echo $RESULT
  	exit $RESULT
  fi
fi

# Create ref index
if [ ! -f ${REF_PREFIX}'.fai' ]; then

  echo "Creating fasta index"
  samtools faidx ${REF}
  
  RESULT=$?
  if [ $RESULT -ne 0 ]; then
  	echo -e "\nCould not create index for  $REF\n"
  	echo $RESULT
  	exit $RESULT
  fi
fi

# Loop through IDs, matching to array nr
FOUND=0

# Assign job id
FOUND=0
for (( i=0; i<${NR_CHRS}; i++ )); do

	j=$((i + 1)) # one offset for task id matching

 	if [ "$j" -eq "${SLURM_ARRAY_TASK_ID}" ]; then
		FOUND=1
		break
	fi
	
done

echo "FOUND: ${FOUND}"
# i=1
# FOUND=1
if [ "${FOUND}" -eq 1 ]; then

  # Call variants
  SAMPLE_IDS_2=$( IFS=$','; echo "${SAMPLE_IDS[*]}" )
  SNP_FILE=${SNP_FILE_IN_DIR}/${SNP_FILE_IN_PREFIX}${CHRS[${i}]}${SNP_FILE_IN_SUFFIX}
  
  BAMS={}
  for ((n=0; n<${NR_SAMPLES}; n++)); do
    BAMS[n]="${BAM_DIR_IN}/${SAMPLE_IDS[${n}]}${BAM_FILE_IN_SUFFIX}/${SAMPLE_IDS[${n}]}${BAM_FILE_IN_SUFFIX}.bam "  #'\\'
  done
  BAMS_2=$( IFS=$'\n'; echo -e "${BAMS[*]}" )
  
  echo "i: ${i}"
  echo "SAMPLE_IDS_2: ${SAMPLE_IDS_2}"
  echo ""
  echo "BAMS_2 ${BAMS_2}"
  echo ""
  echo "SNP_FILE ${SNP_FILE}"
  echo ""

  # Call variants with samtools mpileup
  echo "#############################"
  echo -e "Calling variants for ${BAM_IN} with samtools mpileup"
  date
  TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS
  
  echo "samtools mpileup -R -B -q25 -Q25 \\
  --region ${CHRS[${i}]} \\
  --fasta-ref ${REF} \\
  ${BAMS_2} \\
  | pileupCaller \\
  --mode RandomCalling \\
  --sampleNames ${SAMPLE_IDS_2} \\
  --format EigenStrat \\
  --snpFile ${SNP_FILE} \\
  --eigenstratOutPrefix ${DIR_OUT}/${FILE_OUT_PREFIX}${CHRS[${i}]}
 "

  samtools mpileup -R -B -q25 -Q25 \
      --region ${CHRS[${i}]} \
      --fasta-ref ${REF} \
      ${BAMS_2} \
  | pileupCaller \
    --mode RandomCalling \
    --sampleNames ${SAMPLE_IDS_2} \
    --format EigenStrat \
    --snpFile ${SNP_FILE} \
    --eigenstratOutPrefix ${DIR_OUT}/${FILE_OUT_PREFIX}${CHRS[${i}]}
  
    RESULT=$?
    if [ $RESULT -gt 0 ]; then
      echo -e "\nCannot run mpileup/pileupCaller with bam files\n"
      echo $RESULT
      exit $RESULT
    fi
  
  echo -e "\nCompleted\n"
  
  date
  TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS
  
fi  
