#!/bin/bash
#SBATCH -p skylake                                  # partition
#SBATCH -N 1                                        # number of nodes
#SBATCH -n 2                                        # number of cores
#SBATCH --time=24:00:00                              # time allocation
#SBATCH --mem=1MB									# memory	
#SBATCH --array=2
#SBATCH -o /fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Slurm/Out/%x_%A_%a.out		
#SBATCH -e /fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Slurm/Out/%x_%A_%a.err
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=rick.tearle@adelaide.edu.au

## Bash script to take merged fastq files and split them in to 2 files ##
# The merged file has 8 lines per record, 4 from fastq1 and 4 from fastq2, tab delimited
# Written as a slurm array job, but would need to change array to an array of array for >1 job

SECONDS=0
export TZ='Australia/Adelaide'

echo "#############################"
date
TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS

echo -e "\nSplit_Merged_Fastq_Files-Slurm_Array-2.sh.sh\n"
SLURM_ID=$SLURM_ARRAY_TASK_ID
echo -e "Slurm array task ID: $SLURM_ID\n"

# Variables
DIR_IN='/fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Out/Randomised_Fastq'
#DIR_IN='/Users/rtearle/Documents/My_Projects/Precisely/2019_Aug/Low_Pass_Analysis_2019_Aug/Out/Randomised_Fastq'
FILES_IN=( SRR9091899_1-000-1-Rand.tsv
           SRR9091899_1-001-1-Rand.tsv
           SRR9091899_1-002-1-Rand.tsv
           SRR9091899_1-003-1-Rand.tsv
           SRR9091899_1-004-1-Rand.tsv
           SRR9091899_1-005-1-Rand.tsv
           SRR9091899_1-006-1-Rand.tsv
           SRR9091899_1-007-1-Rand.tsv
           SRR9091899_1-008-1-Rand.tsv
           SRR9091899_1-009-1-Rand.tsv )
#FILES_IN=( SRR9091899_1-000-1-Rand.tsv )
 
MAX_FILE_NR=$((${#FILES_IN[*]} - 1))
 
DIR_OUT='/fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Out/Randomised_Fastq_2'
#DIR_OUT='/Users/rtearle/Documents/My_Projects/Precisely/2019_Aug/Low_Pass_Analysis_2019_Aug/Out/Randomised_Fastq_2'

GZIP=1 

echo "DIR_IN: " ${DIR_IN}
echo "FILES_IN: "
for FILE in ${FILES_IN[@]}; do
  echo -e "\t"${FILE}
done
echo -e "\n"

echo "DIR_OUT: " ${DIR_OUT}
echo "FILE_OUT_PREFIX: " ${FILE_OUT_PREFIX}
echo "FILE_OUT_1: " ${FILE_OUT_1}
echo "FILE_OUT_2: " ${FILE_OUT_2}
echo -e "\n"

mkdir -p ${DIR_OUT}
RESULT=$?
if [ "${RESULT}" -gt 0 ]; then
  echo "Cannot find nor create dir $DIR_OUT"
  echo ${RESULT}
  exit ${RESULT}
fi

echo "#############################"
echo "Splitting merged fastq files"
date
TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS

# Assigning job to job id
FOUND=0
for (( i=0; i<=${MAX_FILE_NR}; i++ )); do

	j=$((i + 1)) # one offset for task id matching

 	if [ $j -eq $SLURM_ARRAY_TASK_ID ]; then
		FOUND=1
		break
	fi
	
done

if [ $FOUND -eq 1 ]; then

  FILE_IN=${FILES_IN[$i]}
  FILE_OUT_1=${FILE_IN/.tsv/_1.fastq}
  FILE_OUT_2=${FILE_IN/.tsv/_2.fastq}
  
  echo "FILE_IN: ${FILE_IN}"
  echo "FILE_OUT_1: ${FILE_OUT_1}"
  echo "FILE_OUT_2: ${FILE_OUT_2}"
  echo -e "\n"

  echo -n "" > ${DIR_OUT}'/'${FILE_OUT_1}
  echo -n "" > ${DIR_OUT}'/'${FILE_OUT_2}

  IFS=$'\t'
  while read -r -a FIELDS; do
  
    printf "%s\n" "${FIELDS[@]:0:4}" >> ${DIR_OUT}'/'${FILE_OUT_1}
    printf "%s\n" "${FIELDS[@]:4:8}" >> ${DIR_OUT}'/'${FILE_OUT_2}
  
  done < ${DIR_IN}'/'${FILE_IN} 
  

  # Randomise merged fastq file
  RESULT=$?
  if [ $RESULT -ne 0 ]
  then
  	echo -e "Could not split merged fastq files\n"
  	echo $RESULT
  	exit $RESULT
  fi
  
  
  if [ "${GZIP}" -eq 1 ]; then

  	gzip ${DIR_OUT}'/'${FILE_OUT_1}
    RESULT=$?
    if [ "$RESULT" -ne 0 ]; then
    	echo -e "Could not gzip fastq file ${FILE_OUT_1}\n"
    	echo $RESULT
    	exit $RESULT
    fi

  	gzip ${DIR_OUT}'/'${FILE_OUT_2}
    RESULT=$?
    if [ "$RESULT" -ne 0 ]; then
    	echo -e "Could not gzip fastq file ${FILE_OUT_2}\n"
    	echo $RESULT
    	exit $RESULT
    fi
  
  fi

  echo "#############################"
  echo "Completed"
  date
  TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS
 
fi 