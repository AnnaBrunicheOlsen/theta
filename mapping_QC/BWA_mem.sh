#!/bin/bash
#SBATCH --job-name=BWA
#SBATCH -A fnrfish
#SBATCH -t 300:00:00 
#SBATCH -N 1 
#SBATCH -n 5 

module load bioinfo
module load bwa

# cd $SLURM_SUBMIT_DIR

#bwa index -a bwtsw ref.fa

rm -rf *bam

ls -d * > files
grep "SRR" files > fastq.txt
less fastq.txt 

cat fastq.txt | while read -r LINE

do

# fastq
bwa mem -t 5 -M -R "@RG\tID:group1\tSM:sample1\tPL:illumina\tLB:lib1\tPU:unit1" \
ref.fa ${LINE}/${LINE}_1_val_1.fq.gz ${LINE}/${LINE}_2_val_2.fq.gz > ${LINE}.sam

done

# END
