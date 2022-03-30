#!/bin/bash
#SBATCH --job-name=S1_Genus-species
#SBATCH -A fnrquail
#SBATCH -t 12-00:00:00 
#SBATCH -N 1 
#SBATCH -n 20
#SBATCH --mem=50G
#SBATCH -e %x_%j.err
#SBATCH -o %x_%j.out

module load bioinfo
module load bioawk
module load seqtk
module load RepeatMasker/4.0.7
module load samtools
module load cmake/3.9.4
module load BEDTools
module load BBMap
module load r
module load bedops
export PATH=$PATH:~/genmap-build/bin

# make sure the Sex Assignment Through Coverage (SATC) codes are downloaded:
# https://github.com/popgenDK/SATC
# link to the SATC.R script for example SATC="/DIR/SATC/satc.R"
# NB: for SATC you need to provide BAM files

####notes####
#
# This script downloads reference, repeat, and annotation data and then identifyies repeats, 
# estimates mappability, identify sex-linked scaffolds and finds all of the short scaffolds. 
# The output files include: 	
# ref.fa (reference file with scaffolds>100kb)							
# ok.bed (regions to analyze in angsd etc)		
# map_repeat_summary.txt (summary of ref quality)							
#
#if a masked genome isn't available (i.e. rm.out), script will create one using the mammal 
#repeat library --- we should change this if we move on from mammals!
#
####usage####
#
#User will need to input (paste) information for the following variables below:
#
#Genus-species: this is used in the directory naming as Erangi suggested, to make browsing
#a bit more doable for us humans
#accession: this is also used in the directory, to keep multiple reference assemblies
#separate as Black suggested
#pathway: include full NCBI url to FTP site (containing directory)                                          
#assembly:name of assembly
#
#Example of defined variables below 
#genus_species=Balaenoptera-musculus
#accession=GCF_009873245.2
#pathway=https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/009/873/245/GCF_009873245.2_mBalMus1.pri.v3/
#assembly=mBalMus1.pri.v3
#Once these have been defined, save and close slurrm job and submit
#sbatch /scratch/bell/$USER/theta/step1_download_QC.sh


 ####end usage and notes####
###########################################
#ENTER INFORMATION FOR FOLLOWING VARIABLES#
###########################################

genus_species=
accession=
pathway=
assembly=

########################
#DO NOT EDIT BELOW CODE#
########################

#Move to JADs scratch space
cd /scratch/bell/dewoody/theta/

####create directories and download reference genome, repeat masker, and annotation####
mkdir -p ./$genus_species/${accession}_ref
mkdir ./$genus_species/${accession}_rm
mkdir ./$genus_species/${accession}_gtf
cd $genus_species

#Download reference genome
cd ${accession}_ref
wget ${pathway}${accession}_${assembly}_genomic.fna.gz 
gunzip ${accession}_${assembly}_genomic.fna
cp ${accession}_${assembly}_genomic.fna original.fa # keep a copy of the original reference
cd ../

#Download repeatmasker file (if available)
cd ${accession}_rm
wget ${pathway}${accession}_${assembly}_rm.out.gz 
gunzip ${accession}_${assembly}.rm.out.gz
cp ${accession}_${assembly}.rm.out rm.out # keep a copy of the original repeatmasker
cd ../

#Download annotation file (if available)
cd ${accession}_gtf
wget ${pathway}${accession}_${assembly}_genomic.gtf.gz 
gunzip ${accession}_${assembly}_genomic.gtf.gz
cp ${accession}_${assembly}_genomic.gtf gtf.gtf # keep a copy of the original annotation
cd ../

#print out file sizes for checking later
ls -lh ${accession}* > download_log

#search for and remove mito seq in ref genome. Will only work if marked in assembly!
grep "mitochondrion" ${accession}_ref/original.fa | cut -f 1 > mito_header.txt #If no mitochondrial sequence present in reference, will be blank. Otherwise contain header
filterbyname.sh include=f in=${accession}_ref/original.fa out=${accession}_ref/original.tmp.fa names="mitochondrion" ow=t substring=t
rm ${accession}_ref/original.fa
mv ${accession}_ref/original.tmp.fa ${accession}_ref/original.fa      

###prep reference genome for mapping####
#Reduce fasta header length
reformat.sh in=${accession}_ref/original.fa out=${accession}_ref/new.fa trd=t -Xmx20g overwrite=T 
#sort by length
sortbyname.sh in=${accession}_ref/new.fa out=${accession}_ref/ref.fa -Xmx20g length descending overwrite=T 
rm ${accession}_ref/new.fa

#index ref
samtools faidx ${accession}_ref/ref.fa


#prep repeatmasked file for later processing, create a rm.out if one is not available. 
cd ${accession}_rm/ #move into rm directory

FILE1=$"rm.out"
if [ -s $FILE1 ]
then
	# change scaffold names to fit ref.fa for rm.out 
	tail -n +4 rm.out > rm.body
	head -n 3 rm.out > rm.header
	sed -i 's/\*//g' rm.body 
	cd /scratch/bell/${USER}/theta/source/
	Rscript repeatmasker_names.R --args /scratch/bell/dewoody/theta/${genus_species}/${accession}_rm ${genus_species} ${accession}
	cd /scratch/bell/dewoody/theta/${genus_species}/${accession}_rm
	sed -i 's/"//g' rm_edited.body 
	cat rm.header rm_edited.body > rm.out
	rm rm_edited.body
	cat rm.out |tail -n +4|awk '{print $5,$6,$7,$11}'|sed 's/ /\t/g' > repeats.bed # make bed file
else	
	# if no rm.out file is available run RepeatMasker. Note, samtools conflict so had to purge first
	module --force purge
	module load biocontainers/default
	module load repeatmasker
	RepeatMasker -pa 5 -a -qq -species mammals ../${accession}_ref/ref.fa 
	cat repeatmasker.fa.out | tail -n +4 | awk '{print $5,$6,$7,$11}' | sed 's/ /\t/g' > repeats.bed  #make bed file
	module --force purge
	module load bioinfo
	module load seqtk
	module load samtools
	module load BEDTools
	module load BBMap
	module load r
fi

cd ../ #move back to species/accession directory

####prep annotation file for later processing####
cd ${accession}_gtf/ #move into gtf directory

FILE1=$"gtf.gtf"
if [ -s $FILE1 ]
then
	# change  names to fit ref.fa and rm.out 
	tail -n +5 gtf.gtf > gtf.body
	head -n 4 gtf.gtf > gtf.header
	cd /scratch/bell/${USER}/theta/source/
	Rscript annotation_names.R --args /scratch/bell/dewoody/theta/${genus_species}/${accession}_gtf ${genus_species} ${accession}
	cd /scratch/bell/dewoody/theta/${genus_species}/${accession}_gtf
	sed -i 's/"//g' gtf_edited.body 
	cat gtf.header gtf_edited.body > gtf.gtf
	rm gtf_edited.body
else	
	# if no rm.out file is available run RepeatMasker
	printf "no annotation availalbe" > log_gtf
fi
#DONE

