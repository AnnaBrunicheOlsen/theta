#!/bin/bash
#SBATCH --job-name=qcRef
#SBATCH -A standby
#SBATCH -t 4:00:00 
#SBATCH -N 1 
#SBATCH -n 1 
#SBATCH --mem=50G

module load bioinfo
module load bioawk
module load seqtk
module load RepeatMasker/4.0.7
module load samtools
module load cmake/3.9.4
module load BEDTools
module load BBMap
module load r
module load bioinfo BBMap/37.93
export PATH=/scratch/bell/dewoody/genmap-build/bin:$PATH

####usage and notes####
#usage:
#step1_download_QC.sh Genus-species accession PUid pathway
#Genus-species: this is used in the directory naming as Erangi suggested, to make browsing 
#a bit more doable for us humans
#accession: this is also used in the directory, to keep multiple reference assemblies
#separate as Black suggested
#PUid: this tells this script where to find the R scripts 
#pathway: include NCBI path up to but not including file extension, e.g.
#/genomes/all/GCF/001/890/085/GCF_001890085.1_ASM189008v1/GCF_001890085.1_ASM189008v1
#
#Example sbatch (we can write a script to create all of these commands later)
#sbatch /scratch/bell/jwillou/theta/step1_ref_download_QC.sh Manis-javanica GCF_001685135.1 /genomes/all/GCF/001/890/085/GCF_001890085.1_ASM189008v1/GCF_001890085.1_ASM189008v1 jwillou
#
#
#Need to have genmap installed and in your path (e.g. export PATH=/home/abruenic/genmap-build/bin:$PATH)
#genmap and installation instructions can be found at: https://github.com/cpockrandt/genmap
#I installed this in DeWoody scratch and then added a PATH update for this location, 
#but we should watch for errors on this step.
#
#Need to have theta git repo cloned 
#
#
#This script downloads reference, repeat, and annotation data and then identifyies repeats, 
#estimates mappability and finds all of the short scaffolds. The output files include: 	
# ref.fa (reference file with scaffolds>100kb)							
# ok.bed (regions to analyze in angsd etc)		
# map_repeat_summary.txt (summary of ref quality)							
#
#if a masked genome isn't available (i.e. rm.out), script will create one using the mammal 
#repeat library --- we should change this if we move on from mammals!
#
####end usage and notes####

genus_species=$1
accession=$2
user=$3
pathway=$4

cd /scratch/bell/dewoody/theta/

####create directories and download reference genome, repeat masker, and annotation####
mkdir -p ./$genus_species/${accession}_ref
mkdir ./$genus_species/${accession}_rm
mkdir ./$genus_species/${accession}_gtf
cd $genus_species

#reference 
wget -O ${accession}_ref/${accession}.fna.gz https://ftp.ncbi.nlm.nih.gov/${pathway}_genomic.fna.gz 
gunzip ${accession}_ref/${accession}.fna.gz
cp ${accession}_ref/${accession}.fna ${accession}_ref/original.fa # keep a copy of the original reference

#repeatmasker
wget -O ${accession}_rm/${accession}.rm.out.gz https://ftp.ncbi.nlm.nih.gov/${pathway}_rm.out.gz 
gunzip ${accession}_rm/${accession}.rm.out.gz
cp ${accession}_rm/${accession}.rm.out ${accession}_rm/rm.out # keep a copy of the original repeatmasker

#annotation
wget -O ${accession}_gtf/${accession}.gtf.gz https://ftp.ncbi.nlm.nih.gov/${pathway}_genomic.gtf.gz 
gunzip ${accession}_gtf/${accession}.gtf.gz
cp ${accession}_gtf/${accession}.gtf ${accession}_gtf/gtf.gtf # keep a copy of the original annotation

#print out file sizes for checking
ls -lh ${accession}* > download_log

####search for and isolate mito seq in ref genome####
grep "mitochondrion" ${accession}_ref/original.fa | cut -f 1 
filterbyname.sh include=f in=${accession}_ref/original.fa out=${accession}_ref/original.tmp.fa names="mitochondrion" ow=t substring=t
rm ${accession}_ref/original.fa
mv ${accession}_ref/original.tmp.fa ${accession}_ref/original.fa      

###prep reference genome for mapping####
sortbyname.sh in=${accession}_ref/original.fa out=${accession}_ref/sorted.fa length descending # sort by length
bioawk -c fastx '{ print ">scaffold-" ++i" "length($seq)"\n"$seq }' < ${accession}_ref/sorted.fa > ${accession}_ref/ref.fa # sort ref

#replace gap and - with _ in scaffold names
sed -i 's/ /_/g' ${accession}_ref/ref.fa
sed -i 's/-/_/g' ${accession}_ref/ref.fa

#index ref
samtools faidx ${accession}_ref/ref.fa

#make table with old and new scaffold names
paste <(grep ">" ${accession}_ref/sorted.fa) <(grep ">" ${accession}_ref/ref.fa) | sed 's/>//g' > ${accession}_ref/scaffold_names.txt

#make file with ID and scaffold identifier, copy it to rm and gtf directories
awk '{ print $1, $NF }' ${accession}_ref/scaffold_names.txt > ${accession}_ref/ID.txt
cp ${accession}_ref/ID.txt ${accession}_rm/ID.txt
cp ${accession}_ref/ID.txt ${accession}_gtf/ID.txt

####prep repeatmasked file for later processing, create a rm.out if one is not available####
cd ${accession}_rm/ #move into rm directory

FILE1=$"rm.out"
if [ -s $FILE1 ]
then
	# change scaffold names to fit ref.fa for rm.out 
	tail -n +4 rm.out > rm.body
	head -n 3 rm.out > rm.header
	sed -i 's/\*//g' rm.body 
	Rscript /scratch/bell/${user}/theta/source/repeatmasker_names.R --args /scratch/bell/dewoody/theta/${genus_species}/${accession}_rm
	#Rscript /scratch/bell/jwillou/theta/source/repeatmasker_names.R --args /scratch/bell/dewoody/theta/Manis-javanica/GCF_011064425.1_rm
	sed -i 's/"//g' rm_edited.body 
	cat rm.header rm_edited.body > rm.out
	cat rm.out |tail -n +4|awk '{print $5,$6,$7,$11}'|sed 's/ /\t/g' > repeats.bed # make bed file
else	
	# if no rm.out file is available run RepeatMasker
	RepeatMasker -qq -species mammal ../${accession}_ref/ref.fa 
	cat repeatmasker.fa.out|tail -n +4|awk '{print $5,$6,$7,$11}'|sed 's/ /\t/g' > repeats.bed  #make bed file
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
	Rscript /scratch/bell/${user}/theta/source/annotation_names.R --args /scratch/bell/dewoody/theta/${genus_species}/${accession}_gtf
	#Rscript /scratch/bell/jwillou/theta/source/annotation_names.R --args /scratch/bell/dewoody/theta/${genus_species}/${accession}_gtf
	sed -i 's/"//g' gtf_edited.body 
	cat gtf.header gtf_edited.body > gtf.gtf
else	
	# if no rm.out file is available run RepeatMasker
	printf "no annotation/gtf availalbe" > log_gtf
fi
cd ../ #move back to species/accession directory

####assess mappability of reference####
rm -rf index
/scratch/bell/dewoody/genmap-build/bin/genmap index -F ${accession}_ref/ref.fa -I index -S 50 # build an index 

# compute mappability, k = kmer of 100bp, E = # two mismatches
mkdir mappability
/scratch/bell/dewoody/genmap-build/bin/genmap map -K 100 -E 2 -I index -O /scratch/bell/dewoody/theta/${genus_species}/mappability -t -w -bg                

# sort bed 
sortBed -i ${accession}_rm/repeats.bed > ${accession}_rm/repeats_sorted.bed 

# make ref.genome
awk 'BEGIN {FS="\t"}; {print $1 FS $2}' ${accession}_ref/ref.fa.fai > ${accession}_ref/ref.genome 

# sort genome file
awk '{print $1, $2, $2}' ${accession}_ref/ref.genome > ${accession}_ref/ref2.genome
sed -i 's/ /\t/g' ${accession}_ref/ref2.genome
sortBed -i ${accession}_ref/ref2.genome > ${accession}_ref/ref3.genome
awk '{print $1, $2 }' ${accession}_ref/ref3.genome > ${accession}_ref/ref_sorted.genome
sed -i 's/ /\t/g' ${accession}_ref/ref_sorted.genome
#rm ${accession}_ref/ref.genome
#rm ${accession}_ref/ref2.genome
#rm ${accession}_ref/ref3.genome

# find nonrepeat regions
bedtools complement -i ${accession}_rm/repeats_sorted.bed -g ${accession}_ref/ref_sorted.genome > ${accession}_rm/nonrepeat.bed

# clean mappability file, remove sites with <1 mappability                                                    
awk '$4 == 1' mappability/mappability.bedgraph > mappability/map.bed                                           
awk 'BEGIN {FS="\t"}; {print $1 FS $2 FS $3}' mappability/map.bed > mappability/mappability.bed
rm mappability/map.bed

# sort mappability 
sortBed -i mappability/mappability.bed > mappability/mappability2.bed
sed -i 's/ /\t/g' mappability/mappability2.bed

# only include sites that are nonrepeats and have mappability ==1
bedtools subtract -a mappability/mappability2.bed -b ${accession}_rm/repeats_sorted.bed > mappability/map_nonreapeat.bed

# sort file -- by chr then site
bedtools sort -i mappability/map_nonreapeat.bed > mappability/filter_sorted.bed

# merge overlapping regions
bedtools merge -i mappability/filter_sorted.bed > mappability/merged.bed

# remove scaffolds shorter than 100kb
bioawk -c fastx '{ if(length($seq) > 100000) { print ">"$name; print $seq }}' ${accession}_ref/ref.fa > ${accession}_ref/ref_100k.fa

# index
samtools faidx ${accession}_ref/ref_100k.fa

# make list with the >10kb scaffolds
awk '{ print $1, $2, $2 }' ${accession}_ref/ref_100k.fa.fai > ${accession}_ref/chrs.info

# replace column 2 with zeros
awk '$2="0"' ${accession}_ref/chrs.info > ${accession}_ref/chrs.bed

# make tab delimited
sed -i 's/ /\t/g' ${accession}_ref/chrs.bed

# make chrs.txt
cut -f 1 ${accession}_ref/chrs.bed > ${accession}_ref/chrs.txt

# only include chr in merged.bed if they are in chrs.txt
bedtools intersect -a ${accession}_ref/chrs.bed -b mappability/merged.bed > ok.bed
	
# remove excess files
rm -rf ${accession}_ref/sorted.fa
rm -rf mappability/merged.bed
rm -rf mappability/filter.bed
rm -rf mappability/map.bed
rm -rf ${accession}_ref/ref_sorted.genome
rm -rf ${accession}_ref/ref.genome
rm -rf ${accession}_rm/repeats.bed
rm -rf ${accession}_ref/sorted.fa

#output some QC stats
Rscript /scratch/bell/${user}/theta/source/qc_reference_stats.R --args /scratch/bell/dewoody/theta/${genus_species}/ $accession
$Rscript /scratch/bell/jwillou/theta/source/qc_reference_stats.R --args /scratch/bell/dewoody/theta/${genus_species}/ $accession

map=$(sed -n '1p' okmap.txt)
repeats=$(sed -n '1p' norepeat.txt)
okbed=$(sed -n '1p' okbed.txt)

echo -e "${genus_species}\t $accession\t $map\t $repeats\t $okbed" >> map_repeat_summary.txt