#!/bin/bash

echo Hello, what is the name of the species genome you are about to download?
read species
echo Creating directory structure for $species, please confirm that it was created correctly

mkdir -p ./$species/${species}_ref
mkdir ./$species/${species}_rm
mkdir ./$species/${species}_gtf
mkdir ./$species/sra
mkdir ./$species/sra/raw
mkdir ./$species/sra/cleaned
mkdir ./$species/sra/aligned

echo Please specify the path to the FTP refseq genome:
read ref

echo Please specify the path to the FTP refseq rm out file:
read rm

echo Please specify the path to the FTP refseq annotations:
read gtf    

echo Downlaoding reference genome, repeat masker out and annotation files. Please check log files and confirm all downloaded correctly
wget $ref -O ./$species/${species}_ref/${species}.genomic.fna.gz -o log_ref 
wget $rm -O ./$species/${species}_rm/${species}.rm.out.gz -o log_rm
wget $gtf -O ./$species/${species}_gtf/${species}.gtf.gz -o log_gtf
echo Downloads are now complete, decompressing files

gzip -d $species/*/*.gz
echo " "

echo Please confirm that all downloaded files were fully downloaded 100%
cat log* | grep "100%" 
echo " "

echo Are all downloaded files named correctly?
ls -lh $species/GCF*
echo " "

echo Now, the reference will be searched for a mitochondrion sequence
grep "mitochondrion" ./$species/${species}_ref/${species}.genomic.fna | cut -f 1 
echo " "
echo If a sequence was printed out, this will now be removed from the reference genome

filterbyname.sh include=f in=./$species/${species}_ref/${species}.genomic.fna out=./$species/${species}_ref/tmp.fasta names="mitochondrion" ow=t substring=t
rm ./$species/${species}_ref/${species}.genomic.fna
mv ./$species/${species}_ref/tmp.fasta ./$species/${species}_ref/${species}.genomic.fna
echo " "
echo DONE, please move on to the SRR download step