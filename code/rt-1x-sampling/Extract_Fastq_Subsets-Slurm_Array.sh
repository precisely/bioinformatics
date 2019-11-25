#!/bin/bash
#SBATCH -p skylake                                  # partition
#SBATCH -N 1                                        # number of nodes
#SBATCH -n 1                                        # number of cores
#SBATCH --time=2:00:00                              # time allocation
#SBATCH --mem=1MB									# memory	
#SBATCH --array=2-10
#SBATCH -o /fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Slurm/Out/%x_%A_%a.out		
#SBATCH -e /fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Slurm/Out/%x_%A_%a.err
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=rick.tearle@adelaide.edu.au

## Bash script to extract a subset of reads from a pair of fastq files ##

SECONDS=0
export TZ='Australia/Adelaide'

echo "#############################"
date
TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS

echo -e "\nExtract_Fastq_Subsets-Slurm_Array.sh\n"
SLURM_ID=$SLURM_ARRAY_TASK_ID
echo -e "Slurm array task ID: $SLURM_ID\n"

# Variables
NR_READS=40000000
NR_SUBSETS=10

DIR_IN='/fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Out/Randomised_Fastq'
DIR_OUT='/fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Out/1x_Sampled_Fastq'

FILE_IN_1='SRR9091899_Rand_1.fastq.gz'
FILE_IN_2='SRR9091899_Rand_2.fastq.gz'

FILE_OUT_TEMPLATE='SRR9091899-1x_0N1-Rand_N2.fastq.gz'

echo "NR_READS: "${NR_READS}
echo ""

echo "DIR_IN: " ${DIR_IN}
echo "FILE_IN_1: "${FILE_IN_1}
echo "FILE_IN_2: "${FILE_IN_2}
echo ""

echo "DIR_OUT: " ${DIR_OUT}
echo "FILE_OUT_TEMPLATE: " ${FILE_OUT_TEMPLATE}
echo -e "\n"

mkdir -p ${DIR_OUT}
RESULT=$?
if [ "${RESULT}" -gt 0 ]; then
  echo "Cannot find nor create dir ${DIR_OUT}"
  echo ${RESULT}
  exit ${RESULT}
fi

# Assigning job to job id
FOUND=0
for (( i=0; i<${NR_SUBSETS}; i++ )); do

	j=$((i + 1)) # one offset for task id matching

 	if [ $j -eq $SLURM_ARRAY_TASK_ID ]; then
		FOUND=1
		break
	fi
	
done

if [ $FOUND -eq 1 ]; then

  HEAD=$((NR_READS * j ))
  TAIL=${NR_READS}

  FILE_OUT_1=${FILE_OUT_TEMPLATE/N1/${i}}
  FILE_OUT_1=${FILE_OUT_1/N2/1}

  FILE_OUT_2=${FILE_OUT_TEMPLATE/N1/${i}}
  FILE_OUT_2=${FILE_OUT_2/N2/2}
  
  echo "FILE_OUT_1: "${FILE_OUT_1}
  echo "FILE_OUT_2: "${FILE_OUT_2}
  echo -e "\n"
  echo "HEAD: "${HEAD}
  echo "TAIL: "${TAIL}
  echo -e ""

  # Extract reads from first file
  echo "#############################"
  echo -e "Extracting ${NR_READS} reads from ${FILE_IN_1}"
  date
  TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS
  
  echo "zcat ${DIR_IN}/${FILE_IN_1} \\
  | head -${HEAD} \\
  | tail -${TAIL} \\
  | gzip \\
  > ${DIR_OUT}/${FILE_OUT_1}"
  
  zcat ${DIR_IN}/${FILE_IN_1} \
  | head -${HEAD} \
  | tail -${TAIL} \
  | gzip \
  > ${DIR_OUT}/${FILE_OUT_1}

  RESULT=$?
  if [ "${RESULT}" -ne 0 ]
  then
  	echo -e "Could not extract reads from ${FILE_IN_1}\n"
  	echo ${RESULT}
  	exit ${RESULT}
  fi

  # Extract reads from second file
  echo "#############################"
  echo -e "Extracting ${NR_READS} reads from ${FILE_IN_2}"
  date
  TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS
  
  echo "zcat ${DIR_IN}/${FILE_IN_2} \\
  | head -${HEAD} \\
  | tail -${TAIL} \\
  | gzip \\
  > ${DIR_OUT}/${FILE_OUT_2}"

  zcat ${DIR_IN}/${FILE_IN_2} \
  | head -${HEAD} \
  | tail -${TAIL} \
  | gzip \
  > ${DIR_OUT}/${FILE_OUT_2}

  RESULT=$?
  if [ "${RESULT}" -ne 0 ]
  then
  	echo -e "Could not extract reads from ${FILE_IN_2}\n"
  	echo ${RESULT}
  	exit ${RESULT}
  fi
  
  echo "#############################"
  echo "Completed"
  date
  TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS
 
fi 