#!/bin/bash
#SBATCH -p batch                                      # partition
#SBATCH -N 1                                            # number of nodes
#SBATCH -n 4                                            # number of cores
#SBATCH --time=0-02:00:00                                  # time allocation
#SBATCH --mem=8GB 									    # memory
#SBATCH --array=4,8-10
#SBATCH -o /fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Align_Call_2019_Aug/Slurm/Out/%x_%A_%a.out		
#SBATCH -e /fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Align_Call_2019_Aug/Slurm/Out/%x_%A_%a.err
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=rick.tearle@adelaide.edu.au

## Bash script to align reads against a reference genome ##

SECONDS=0

echo "#############################"
date
TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS

echo -e "\nAlign_Short_Reads_2_Reference-Slurm_Array.sh"
SLURM_ID=$SLURM_ARRAY_TASK_ID
echo -e "Slurm array task ID: $SLURM_ID\n"

# Modules
echo "#############################"
MODULES=( Java/1.8.0_121 
          BWA/0.7.15-foss-2017a
          SAMtools/1.8-foss-2016b
          )
# SAMtools/1.9-foss-2016b 
         
for MODULE in ${MODULES[@]}
do
	module load $MODULE
	
	RESULT=$?
	if [ $RESULT -ne 0 ]
	then
		echo -e "Could not load $MODULE\n"
		echo $RESULT
		exit $RESULT
	else
		echo -e "Loading module $MODULE"
	fi

done

echo -e '\nPICARD_HOME: '${PICARD_HOME}

echo -e "\n"

# Setting variables
READS_PREFIXES=( SRR9091899-1x_00-Rand SRR9091899-1x_01-Rand SRR9091899-1x_02-Rand SRR9091899-1x_03-Rand SRR9091899-1x_04-Rand 
                 SRR9091899-1x_05-Rand SRR9091899-1x_06-Rand SRR9091899-1x_07-Rand SRR9091899-1x_08-Rand SRR9091899-1x_09-Rand  )

IDS=( NA12978-0 NA12978-1 NA12978-2 NA12978-3 NA12978-4 
      NA12978-5 NA12978-6 NA12978-7 NA12978-8 NA12978-9 )

NR_SAMPLES=${#READS_PREFIXES[*]}

LIBS=( A00559_9_H3JKFDRXX_GB-WGSNA12878 A00559_9_H3JKFDRXX_GB-WGSNA12878 A00559_9_H3JKFDRXX_GB-WGSNA12878 A00559_9_H3JKFDRXX_GB-WGSNA12878 A00559_9_H3JKFDRXX_GB-WGSNA12878 
       A00559_9_H3JKFDRXX_GB-WGSNA12878 A00559_9_H3JKFDRXX_GB-WGSNA12878 A00559_9_H3JKFDRXX_GB-WGSNA12878 A00559_9_H3JKFDRXX_GB-WGSNA12878 A00559_9_H3JKFDRXX_GB-WGSNA12878 )

REF='/fast/users/a1222182/Genomes/Human_Genome/GRCh38/BWA/Homo_sapiens.GRCh38.dna.primary_assembly.fa'
REF_NAME='GRCh38'

READ_DIR='/fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Sample_Reads_2019_Aug/Out/1x_Sampled_Fastq'
READ_SUFFIX_1='_1.fastq.gz'
READ_SUFFIX_2='_2.fastq.gz'

DIR_OUT='/fast/users/a1222182/Human/NA12878_2019_Aug/2019_Aug/Low_Pass_Analysis_2019_Aug/Out/Alignments'

THREADS=4

echo "REF : "${REF}
echo "REF_NAME : "${REF_NAME}
echo "READ_DIR : "${READ_DIR}
echo "READ_SUFFIX_1 : "${READ_SUFFIX_1}
echo "READ_SUFFIX_2 : "${READ_SUFFIX_2}
echo "DIR_OUT : "${DIR_OUT}

FOUND=0
for (( i=0; i<${NR_SAMPLES}; i++ )); do

	j=$((i + 1)) # one offset for task id matching

 	if [ "$j" -eq "${SLURM_ARRAY_TASK_ID}" ]; then
		FOUND=1
		break
	fi
	
done

echo "FOUND : "${FOUND}

if [ "${FOUND}" -eq 1 ]; then

  # Variables
  ID=${IDS[$i]}
  READS_PREFIX=${READS_PREFIXES[$i]}

  READS_1=${READ_DIR}/${READS_PREFIX}${READ_SUFFIX_1}
  READS_2=${READ_DIR}/${READS_PREFIX}${READ_SUFFIX_2}
  
  RGPL='ILLUMINA'
  RGLB=${LIBS[$i]}
  RG='@RG\tID:'"${ID}"'\tPL:'"${RGPL}"'\tLB:'"${RGLB}"'\tSM:'"${ID}"

  FILE_OUT_PREFIX=${ID}'-vs-'${REF_NAME}
  DIR_OUT_2=${DIR_OUT}/${REF_NAME}/${FILE_OUT_PREFIX}

  BAM_TEMP=${FILE_OUT_PREFIX}'-temp.bam'
  BAM=${FILE_OUT_PREFIX}'.bam'

  DUP_METRICS=${FILE_OUT_PREFIX}'-Dup_Metrics.txt'
  INDEX_STATS=${FILE_OUT_PREFIX}'-Index_Stats.txt'
  SUM_METRICS=${FILE_OUT_PREFIX}'-Summary_Metrics.txt'
  VAL_SAM=${FILE_OUT_PREFIX}'-Validate_Summary.txt'      

  echo -e "#############################"
  echo -e 'REF_NAME: '${REF_NAME}
  echo -e "\n"

  echo -e 'ID: '${ID}  
  echo -e 'READ_DIR: '${READ_DIR}  
  echo -e 'READS_PREFIX: '${READS_PREFIX}
  echo -e 'READS_1: '${READS_1}
  echo -e 'READS_2: '${READS_2}

  echo -e '\nFILE_OUT_PREFIX: '${FILE_OUT_PREFIX}
  echo -e 'RGPL: '${RGPL}
  echo -e 'RGLB: '${RGLB}
  echo -e 'RG: '${RG}

  echo -e '\nDIR_OUT: '${DIR_OUT}
  echo -e 'DIR_OUT_2: '${DIR_OUT_2}
  echo -e 'BAM_TEMP: '${BAM_TEMP}
  echo -e 'BAM: '${BAM}

  echo -e '\nDUP_METRICS: '${DUP_METRICS}
  echo -e 'INDEX_STATS: '${INDEX_STATS}
  echo -e 'SUM_METRICS: '${SUM_METRICS}
  echo -e 'VAL_SAM: '${VAL_SAM}
  echo -e "\n"

  mkdir -p ${DIR_OUT_2}
  RESULT=$?
  if [ "$RESULT" -ne 0 ]
  then
    echo -e "Could not create/access output dir ${DIR_OUT_2}\n"
    echo $RESULT
    exit $RESULT
  fi
  
  cd ${DIR_OUT_2}
  if ! [[ "$PWD" =~ "${DIR_OUT_2}" ]]; then
    echo "Cannot enter dir ${DIR_OUT_2}"
    exit
  fi

  # Create ref index
  if [ ! -f ${REF_PREFIX}'.amb' ]; then
  
    echo "#############################"
    echo -e "Indexing ${REF}"
    date
    TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS
    echo "bwa index ${REF}\n"
  
    bwa index ${REF}
    
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
      echo -e "\nCould not index $REF\n"
    	echo $RESULT
    	exit $RESULT
    fi
    
  fi

  echo -e "\n"
  
  ## Align ##
  echo "#############################"
  echo -e "Aligning ${READS_PREFIX} to ${REF_NAME}"
  date
  TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS
  
  
  echo -e "\nbwa mem \\
    -M \\
    -t $THREADS \\
    -R @RG\\tID:${PREFIX}\\tPL:${RGPL}\\tLB:${RGLB}\\tSM:${INTERNATIONALID} \\
    ${REF} \\
    ${READS_1} \\
    ${READS_2} \\
    | samtools sort - -O BAM -o ${DIR_OUT_2}/${BAM_TEMP}\n"
    
  bwa mem \
    -M \
    -t $THREADS \
    -R "$RG" \
    ${REF} \
    ${READS_1} \
    ${READS_2} \
    | samtools sort - -O BAM -o ${DIR_OUT_2}/${BAM_TEMP}
    
    # @RG\tID:\tPL:ILLUMINA\tLB:A00559_9_H3JKFDRXX_GB-WGSNA12878\tSM:NA12978-0
    # @RG\tID:${PREFIX}\tPL:${RGPL}\tLB:${RGLB}\tSM:${ID}
    # @RG\tID:foo\tSM:bar
	    
  RESULT=$?
  if [ "${RESULT}" -ne 0 ]
  then
  	echo -e "Could not align ${READS_PREFIX} to ${REF_NAME}\n"
  	echo ${RESULT}
  	exit ${RESULT}
  fi
    
  echo -e "\n"

  echo -e "Renaming ${BAM_TEMP} to ${BAM}"

  mv ${DIR_OUT_2}/${BAM_TEMP} ${DIR_OUT_2}/${BAM}
  
  RESULT=$?
  if [ "${RESULT}" -ne 0 ]
  then
    echo -e "Could not rename ${BAM_TEMP} to ${BAM}\n"
    echo ${RESULT}
    exit ${RESULT}
  fi

  echo -e "\n"

  # Mark duplicates
  echo "#############################"
  echo -e "Marking duplicates in ${BAM}"
  date
  TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS
  
  #OPTICAL_DUPLICATE_PIXEL_DISTANCE=100 # non-arrayed flowcells GAIIx, HiSeq1500/2000/2500
  OPTICAL_DUPLICATE_PIXEL_DISTANCE=2500 # arrayed flowcells  HiSeqX, HiSeq3000/4000, NovaSeq
  #OPTICAL_DUPLICATE_PIXEL_DISTANCE=2500 # arrayed flowcells  BGI-SEQ500
  
  echo -e "java -jar picard.2.18.2.jar MarkDuplicates \\
    I=${DIR_OUT_2}/${BAM} \\
    O=${DIR_OUT_2}/${BAM_TEMP} \\
    M=${DIR_OUT_2}/${DUP_METRICS} \\
    OPTICAL_DUPLICATE_PIXEL_DISTANCE=${OPTICAL_DUPLICATE_PIXEL_DISTANCE} \\
    CREATE_INDEX=true \\
    VALIDATION_STRINGENCY=LENIENT\n"
  
  java -Xmx80G -jar $PICARD_HOME/picard.2.18.2.jar MarkDuplicates \
    I=${DIR_OUT_2}/${BAM} \
    O=${DIR_OUT_2}/${BAM_TEMP} \
    M=${DIR_OUT_2}/${DUP_METRICS} \
    OPTICAL_DUPLICATE_PIXEL_DISTANCE=${OPTICAL_DUPLICATE_PIXEL_DISTANCE} \
    CREATE_INDEX=false \
    VALIDATION_STRINGENCY=LENIENT  

    # TMP_DIR=${FASTTMP_DIR} \

  RESULT=$?
  if [ $RESULT -ne 0 ]
  then
    echo -e "Could not mark duplicates in ${BAM}\n"
    echo $RESULT
    exit $RESULT
  fi
  
  echo -e "Renaming ${BAM_TEMP} to ${BAM}"
  
  mv ${DIR_OUT_2}/${BAM_TEMP} ${DIR_OUT_2}/${BAM}
  
  RESULT=$?
  if [ $RESULT -ne 0 ]
  then
    echo -e "Could not rename ${BAM_TEMP} to ${BAM}\n"
    echo $RESULT
    exit $RESULT
  fi
  
  echo -e "\n"
  
  # Index 
  echo "#############################"
  echo -e "Indexing ${BAM}\n"
  date
  TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS
  
  echo -e "samtools index ${DIR_OUT_2}/${BAM}\n"
  
  samtools index ${DIR_OUT_2}/${BAM}
  
  RESULT=$?
  if [ $RESULT -ne 0 ]
  then
    echo -e "Could not index ${BAM}\n"
    echo $RESULT
    exit $RESULT
  fi
  
  echo -e "\n"
  
  # BamIndexStats
  echo "#############################"
  echo -e "Getting index stats for ${BAM}"
  date
  TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS
  
  echo -e "java -jar $PICARD_HOME/picard.2.18.2.jar BamIndexStats \\
    I=${DIR_OUT_2}/${BAM} \\
    > ${DIR_OUT_2}/${INDEX_STATS}\n"
  		
  java -jar $PICARD_HOME/picard.2.18.2.jar BamIndexStats \
    I=${DIR_OUT_2}/${BAM} \
    > ${DIR_OUT_2}/${INDEX_STATS}
  		
  RESULT=$?
  if [ $RESULT -ne 0 ]
  then
    echo -e "Could not run picard BamIndexStats on ${BAM}\n"
    echo $RESULT
    exit $RESULT
  fi
  
  echo -e "\n"
  
  # CollectAlignmentSummaryMetrics
  echo "#############################"
  echo -e "Collecting alignment summary metrics for ${BAM}"
  date
  TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS
  
  echo -e "java -jar $PICARD_HOME/picard.2.18.2.jar CollectAlignmentSummaryMetrics \\
    R=${REF} \\
    I=${DIR_OUT_2}/${BAM} \\
    O=${DIR_OUT_2}/${SUM_METRICS}\n"
  
  java -jar $PICARD_HOME/picard.2.18.2.jar CollectAlignmentSummaryMetrics \
    R=${REF} \
    I=${DIR_OUT_2}/${BAM} \
    O=${DIR_OUT_2}/${SUM_METRICS}
  
  RESULT=$?
  if [ $RESULT -ne 0 ]
  then
    echo -e "Could not run picard CollectAlignmentSummaryMetrics on ${BAM}\n"
    echo $RESULT
    exit $RESULT
  fi
  
  echo -e "\n"
  
  # Validate file
  echo "#############################"
  echo -e "Validating Bam file ${BAM}"
  date
  TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS
  
  echo -e "java -jar $PICARD_HOME/picard.2.18.2.jar ValidateSamFile \\
    I=${DIR_OUT_2}/${BAM} \\
    MODE=SUMMARY \\
    > ${DIR_OUT_2}/${VAL_SAM}\n"
    
  java -jar $PICARD_HOME/picard.2.18.2.jar ValidateSamFile \
    I=${DIR_OUT_2}/${BAM} \
    MODE=SUMMARY \
    > ${DIR_OUT_2}/${VAL_SAM}
  
  RESULT=$?
  if [ $RESULT -ne 0 ]
  then
    echo -e "Validation of ${BAM} failed\n"
    echo $RESULT
    #exit $RESULT
  fi
  
  echo -e "\nCompleted\n"
  
  date
  TZ=UTC0 printf '%(%H:%M:%S)T\n\n' $SECONDS

  #rm -rf ${FASTTMP_DIR}
  
else

 echo "Job Array ID ${SLURM_ID} not matched"
  
fi


