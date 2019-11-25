#!/bin/bash
#SBATCH -p skylake                                  # partition
#SBATCH -N 1                                        # number of nodes
#SBATCH -n 1                                        # number of cores
#SBATCH --time=02:00:00                              # time allocation
#SBATCH --mem=1MB									# memory	
#SBATCH --array=1
#SBATCH -o /fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Slurm/Out/%x_%A_%a.out		
#SBATCH -e /fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Slurm/Out/%x_%A_%a.err
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=rick.tearle@adelaide.edu.au

## Bash script to concatenate merged fastq files and split them in to 2 files ##
# The merged file has 8 lines per record, 4 from fastq1 and 4 from fastq2, tab delimited
# Written as a slurm array job, but would need to change array to an array of array for >1 job

SECONDS=0
export TZ='Australia/Adelaide'

echo "#############################"
date
TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS

echo -e "\nSplit_Merged_Fastq_Files-Slurm_Array.sh.sh\n"
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
FILES_IN=( SRR9091899_1-000-1-Rand.tsv )
 
MAX_FILE_NR=$((${#FILES_IN[*]} - 1))
 
DIR_OUT='/fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Out/Randomised_Fastq_2'
#DIR_OUT='/Users/rtearle/Documents/My_Projects/Precisely/2019_Aug/Low_Pass_Analysis_2019_Aug/Out/Randomised_Fastq_2'
FILE_OUT_PREFIX='SRR9091899'
FILE_OUT_1=${FILE_OUT_PREFIX}"-Rand_1.fastq"
FILE_OUT_2=${FILE_OUT_PREFIX}"-Rand_2.fastq"

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

# Function takes in tabbed delimited line, first 4 to file 1, next 4 to file 2
function SplitLine () {
  while IFS=$'\t' read -r -a FIELDS; do
  
    for n in {0..3}; do
      echo -e "${FIELDS[n]}" >> ${DIR_OUT}'/'${FILE_OUT_1}
    done 
    
    for n in {4..7}; do
      echo -e "${FIELDS[n]}" >> ${DIR_OUT}'/'${FILE_OUT_2}
    done
        
  done
}

# Assigning job to job id
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

  echo -n "" > ${DIR_OUT}'/'${FILE_OUT_1}
  echo -n "" > ${DIR_OUT}'/'${FILE_OUT_2}

  COMMAND="cat "'\\'
  
  for FILE in ${FILES_IN[@]}; do
    STRING=" ${DIR_IN}/${FILE} "'\\'
    COMMAND=${COMMAND}"\n"${STRING}
  done

  STRING=' | SplitLine'
  COMMAND=${COMMAND}"\n"${STRING}


  # Split merged fastq file
  echo -e ${COMMAND}
  
  COMMAND2=$(echo -e ${COMMAND} | sed 's/\\//g')
   
  eval ${COMMAND2}  

  RESULT=$?
  if [ $RESULT -ne 0 ]
  then
  	echo -e "Could not split merged fastq files\n"
  	echo $RESULT
  	exit $RESULT
  fi
  
  
  if [ "${GZIP}" -eq 1 ]; then

  	gzip > ${DIR_OUT}'/'${FILE_OUT_1}
    RESULT=$?
    if [ "$RESULT" -ne 0 ]; then
    	echo -e "Could not split gzip fastq file ${FILE_OUT_1}\n"
    	echo $RESULT
    	exit $RESULT
    fi

  	gzip > ${DIR_OUT}'/'${FILE_OUT_2}
    RESULT=$?
    if [ "$RESULT" -ne 0 ]; then
    	echo -e "Could not split gzip fastq file ${FILE_OUT_2}\n"
    	echo $RESULT
    	exit $RESULT
    fi
  
  fi

  echo "#############################"
  echo "Completed"
  date
  TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS
 
fi 