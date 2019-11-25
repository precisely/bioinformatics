#!/bin/bash
#SBATCH -p skylake                                        # partition
#SBATCH -N 1                                            # number of nodes
#SBATCH -n 1                                         # number of cores
#SBATCH --time=4:00:00                               # time allocation
#SBATCH --mem=1MB 									# memory	
#SBATCH --array=1
#SBATCH -o /fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Slurm/Out/%x_%A_%a.out		
#SBATCH -e /fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Slurm/Out/%x_%A_%a.err
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=rick.tearle@adelaide.edu.au

## Bash script wrapper for python script Random_Split_Assign_Fastq.py
# The python script takes the 4 lines for a record, from the 2 paired files and  merges them to 1 line with tab delimiters
# The lines are then written at random to one of a number of output files

SECONDS=0
export TZ='Australia/Adelaide'

echo "#############################"
date
TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS

echo -e "\nPython_Random_Split_Assign_Fastq_Wrapper-Slurm_Array.sh\n"
SLURM_ID=$SLURM_ARRAY_TASK_ID
echo -e "Slurm array task ID: $SLURM_ID\n"

# Variables
FILE_IN_1='/fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Raw_Data/SRR9091899_1.fastq.gz'
FILE_IN_2='/fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Raw_Data/SRR9091899_2.fastq.gz'
# FILE_IN_1='/fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Raw_Data/SRR9091899_Head_1.fastq.gz'
# FILE_IN_2='/fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Raw_Data/SRR9091899_Head_2.fastq.gz'
DIR_OUT='/fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Out/Merge_Split_Fastq'
NR_FILES=10

mkdir -p ${DIR_OUT}
RESULT=$?
if [ "${RESULT}" -gt 0 ]; then
  echo "Cannot find nor create dir $DIR_OUT"
  echo ${RESULT}
  exit ${RESULT}
fi

SCRIPT_HOME='/home/a1222182/python/scripts/dev'

echo "#############################"
echo "Merging fastq pair records and writing randomly to output files"
date
TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS

# Randomise fastq file pair
echo "python2.7 ${SCRIPT_HOME}/Random_Split_Assign_Fastq_0_0_1.py \\
  --fastq_1 ${FILE_IN_1} \\
  --fastq_2 ${FILE_IN_2} \\
  --dir_out ${DIR_OUT} \\
  --nr_files ${NR_FILES}
  "
  
python2.7 ${SCRIPT_HOME}/Random_Split_Assign_Fastq_0_0_1.py \
  --fastq_1 ${FILE_IN_1} \
  --fastq_2 ${FILE_IN_2} \
  --dir_out ${DIR_OUT} \
  --nr_files ${NR_FILES}
  
RESULT=$?
if [ $RESULT -ne 0 ]
then
	echo -e "Could not merge and randomly save fastq file pair\n"
	echo $RESULT
	exit $RESULT
fi

echo "#############################"
echo "Completed"
date
TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS
 
