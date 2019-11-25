#!/bin/bash
#SBATCH -p batch                                         # partition
#SBATCH -N 1                                             # number of nodes
#SBATCH -n 4                                             # number of cores
#SBATCH --time=5:00:00                                  # time allocation
#SBATCH --mem=8GB 										 # memory
#SBATCH --array=2-4,6,8
#SBATCH -o /fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Align_Call_2019_Aug/Slurm/Out/%x_%A_%a.out		
#SBATCH -e /fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Align_Call_2019_Aug/Slurm/Out/%x_%A_%a.err
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=rick.tearle@adelaide.edu.au

## Bash script to call variants ##
echo "#############################"
echo -e "Call_Variants_by_Chr-Slurm_Array.sh"
date
TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS

SLURM_ID=$SLURM_ARRAY_TASK_ID
echo -e "Slurm array ID: $SLURM_ID\n"

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

echo -e "\n"

# Variables
DIR_IN='/fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Out/Alignments/GRCh38'
FILE_PREFIX='-vs-GRCh38'

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

CHRS=( 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 X Y MT )

NR_SAMPLES=${#SAMPLE_IDS[*]}

DIR_OUT='/fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Out/Alignments/GRCh38'

if [[ ! -e "${DIR_OUT}" ]]; then 
  mkdir -p $DIR_OUT

  RESULT=$?
  if [ $RESULT -ne 0 ]; then
    echo "Cannot find nor create dir $DIR_OUT" 
    echo $RESULT
    exit $RESULT
  fi
fi

# Genome or chr reference
REF_SUFFIX='/fast/users/a1222182/Genomes/Human_Genome/GRCh38/BWA/Homo_sapiens.GRCh38.dna.primary_assembly'
REF=${REF_SUFFIX}'.fa'

echo "REF: ${REF}"
echo "REF_SUFFIX: ${REF_SUFFIX}"
echo ""
echo "DIR_IN: ${DIR_IN}"
echo "DIR_OUT: ${DIR_OUT}"
echo "FILE_PREFIX: ${FILE_PREFIX}"
echo ""
echo "SAMPLE_IDS: ${SAMPLE_IDS[@]}"
echo "SEXES: ${SEXES[@]}"
echo "CHRS: ${CHRS[@]}"
echo ""
echo "NR_CHRS: ${NR_CHRS}"
echo "NR_SAMPLES: ${NR_SAMPLES}"
echo ""

# Create seq dict
if [ ! -f ${REF_SUFFIX}'.dict' ]; then

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
if [ ! -f ${REF}'.fai' ]; then

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
for (( i=0; i<${NR_SAMPLES}; i++ )); do

	j=$((i + 1)) # one offset for task id matching

 	if [ "$j" -eq "${SLURM_ARRAY_TASK_ID}" ]; then
		FOUND=1
		break
	fi
	
done

echo "FOUND: ${FOUND}"

if [ "${FOUND}" -eq 1 ]; then

  # Call variants
  SAMPLE_ID=${SAMPLE_IDS[$i]}

  DIR_IN_2=${DIR_IN}'/'${SAMPLE_ID}${FILE_PREFIX}

  BAM_IN=${SAMPLE_ID}${FILE_PREFIX}'.bam'
  
  echo "i: ${i}"
  echo "j: ${j}"
  echo "SAMPLE_ID: "${SAMPLE_ID}
  
  echo -e "\nREF: "${REF}
  echo "DIR_IN_2: "${DIR_IN_2}
  echo "BAM_IN: "${BAM_IN}

  
  # Call variants with GATK
  echo "#############################"
  echo -e "Calling variants for ${BAM_IN} with GATK HaplotypeCaller"
  date
  TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS
  
  VCF=${SAMPLE_ID}${FILE_PREFIX}/${SAMPLE_ID}${FILE_PREFIX}'.g.vcf.gz'
  VCF_TMP=${SAMPLE_ID}${FILE_PREFIX}/${SAMPLE_ID}${FILE_PREFIX}'-TMP.g.vcf.gz'

  echo -e "gatk HaplotypeCaller  \\
    -R $REF \\
    -L chrMT \\
    -I ${DIR_IN_2}/$BAM_IN \\
    -O ${DIR_OUT}/$VCF_TMP \\
    --emit-ref-confidence GVCF
    \n"
	
  gatk HaplotypeCaller  \
    -R $REF \
    -L chrMT \\
    -I ${DIR_IN_2}/$BAM_IN \
    -O ${DIR_OUT}/$VCF_TMP \
    --emit-ref-confidence GVCF 

  RESULT=$?
  if [ $RESULT -gt 0 ]; then
    echo -e "\nCannot run GATK with ${BAM_IN}\n"
    echo $RESULT
    exit $RESULT
  fi
  
  echo -e "\nRenaming ${VCF_TMP} as ${VCF}"
  mv ${DIR_OUT}/${VCF_TMP} ${DIR_OUT}/${VCF}
  
  RESULT=$?
  if [ $RESULT -ne 0 ]
  then
    echo -e "Could not rename ${VCF_TMP} as ${VCF}\n"
    echo $RESULT
    exit $RESULT
  fi
    
  # Tabixing
  echo -e "tabix $VCF\n"

  tabix --preset vcf $VCF

  RESULT=$?
  if [ "${RESULT}" -gt 0 ]; then
    echo -e "\nCannot run tabix with ${VCF}\n"
    echo ${RESULT}
    exit ${RESULT}
  fi

    # Index vcf
#     echo "#############################"
#     echo -e "Indexing ${VCF}"
#     date
#     TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS
# 	    
#     bcftools index $VCF
# 
#     if [ $RESULT -gt 0 ]; then
#       echo -e "\nCannot index ${VCF}\n"
#       echo $RESULT
#       exit $RESULT
#     fi
    

  
  echo -e "\nCompleted\n"
  
  date
  TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS
  
fi  
