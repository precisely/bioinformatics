#!/bin/bash
#SBATCH -p skylake                                  # partition
#SBATCH -N 1                                        # number of nodes
#SBATCH -n 2                                        # number of cores
#SBATCH --time=00:20:00                              # time allocation
#SBATCH --mem=48GB									# memory	
#SBATCH --array=2-10
#SBATCH -o /fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Slurm/Out/%x_%A_%a.out		
#SBATCH -e /fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Slurm/Out/%x_%A_%a.err
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=rick.tearle@adelaide.edu.au

## Bash script to randomise merged fastq files ##
# This script uses the output from python script Random_Split_Assign_Fastq.py
# This python script takes the 4 lines for a record, from the 2 paired files, are merges them to 1 line with tab delimiters

SECONDS=0
export TZ='Australia/Adelaide'

echo "#############################"
date
TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS

echo -e "\nRandomise_Merged_Fastq_Files-Slurm_Array.sh\n"
SLURM_ID=$SLURM_ARRAY_TASK_ID
echo -e "Slurm array task ID: $SLURM_ID\n"

# Variables
DIR_IN='/fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Out/Merge_Split_Fastq'
FILES_IN=( SRR9091899_1-000-1.tsv
           SRR9091899_1-001-1.tsv
           SRR9091899_1-002-1.tsv
           SRR9091899_1-003-1.tsv
           SRR9091899_1-004-1.tsv
           SRR9091899_1-005-1.tsv
           SRR9091899_1-006-1.tsv
           SRR9091899_1-007-1.tsv
           SRR9091899_1-008-1.tsv
           SRR9091899_1-009-1.tsv
 )
 
MAX_FILE_NR=$((${#FILES_IN[*]} - 1))
 
DIR_OUT='/fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Out/Randomised_Fastq'

mkdir -p ${DIR_OUT}
RESULT=$?
if [ "${RESULT}" -gt 0 ]; then
  echo "Cannot find nor create dir $DIR_OUT"
  echo ${RESULT}
  exit ${RESULT}
fi

echo "#############################"
echo "Randomising merged fastq files"
date
TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS

FOUND=0
#for i in {0..${MAX_FILE_NR}}; do # zero offset for arrays
for (( i=0; i<=${MAX_FILE_NR}; i++ )); do

	j=$((i + 1)) # one offset for task id matching

 	if [ $j -eq $SLURM_ARRAY_TASK_ID ]; then
		FOUND=1
		break
	fi
	
done

if [ $FOUND -eq 1 ]; then


  FILE_IN=${FILES_IN[$i]}
  
  FILE_OUT=${FILE_IN/.tsv/-Rand.tsv}
  if ! [[ "${FILE_IN}" != "${FILE_OUT}" ]]; then
    echo "Cannot give output file a different name to input file"
    exit 1
  fi
  
  # Randomise merged fastq file
  echo "shuf \\
    --output ${DIR_OUT}/${FILE_OUT} \\
    ${DIR_IN}/${FILE_IN}
  "
  
  shuf \
    --output ${DIR_OUT}'/'${FILE_OUT} \
    ${DIR_IN}'/'${FILE_IN}
  
  RESULT=$?
  if [ $RESULT -ne 0 ]
  then
  	echo -e "Could not randomise merged fastq file\n"
  	echo $RESULT
  	exit $RESULT
  fi


  echo "#############################"
  echo "Completed"
  date
  TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS
 
fi 