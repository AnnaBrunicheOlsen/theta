# Theta project
Jan 2021

These scripts are developed for investigating genomic diversity and effective population size (θ = 4Neμ) in wildlife populations. NOTE, these scripts assume that a SLURM scheduler is used; if a different scheduler is employed (e.g., SGE) please modify script headers and module loads accordingly).

## Finding the population data

1.	Population data can be found from publications (Google scholar etc.), NCBI website, and ebi.ac.uk website …(Andrew Black’s “Zipped directory” is also helpful!)
- Check the species carefully, sometimes they are the host, so they did not get sequenced

2.	Look for Whole-genome resequencing data from Illumina Hiseq or Novaseq technologies  
- Record S2 and S4 lane reads seperately
- As per: https://onlinelibrary.wiley.com/doi/10.1111/1755-0998.13309

3. Minimum read length should be 150 bps

4.	The individuals only be selected from wild populations  
-	Exclude laboratory-bred, captive-bred ..etc. populations  

5.	Most of the papers have a section named ‘data availability’ 
-	This section has the BioProject accession number(PRJNAxx…) which you can follow to find SRAs
-	Follow the Supplementary information section of the paper for more information if available

6.	Per species, SRAs from a maximum of 8 individuals should be collected
-	These 8 individuals should belong to one population
-	If there are multiple populations take one population with 8 individuals. If all the populations are less than 8 individuals, take the one with the highest number
For an instance, if there are 2 populations per one species each with 6 and 4 individuals only the population with 6 individuals take into account
-	There should be at least 2 individuals per species (minimum number) to include in the project

6.	Make sure each SRA belongs to one individual and 8 SRAs belong to 8 different individuals
-	There can be multiple SRAs for one individual and these multiple SRAs can be included in the project. The pipeline is developed with a space to add multiple SRAs. 


## Steps for analyzing each species (one at a time)

STEP 1: Start an interactive session:

Begin an interactive session to move to a back-end machine:
```
#Start an interactive session on standby
sinteractive -t 4:00:00 --mem=10G
```

STEP 2: Create folder structure and download reference genome, repeater masker out file and annotations (if available). NOTE, below the Cheetah genome is used as an example only. User's will need to designate the genome assembly for the species they are targetting. 

a) For a current list of all mammalian refseq assemblies, go to: https://www.ncbi.nlm.nih.gov/datasets/genomes/?txid=40674&source_db=RefSeq
and locate your species of interest. 

b) Identify the best / most current assembly (based upon N50, assembly levlel, etc) and click on the refseq hyperlink beginning with "GCF_", which will link to the NCBI genome summary web-page. 

Once here, locate and navigate to the "FTP directory for RefSeq assembly" in the right hand column. This will pull up the File Transfer Protocal web page where the reference genome (e.g. GCF_002007445.1_ASM200744v2_genomic.fna.gz), repeat masker out (e.g. GCF_002007445.1_ASM200744v2_rm.out.gz) and annotations (e.g. GCF_002007445.1_ASM200744v2_genomic.gtf.gz) are available for download. 

Copy the name of the reference genome build, and the link addresses to all three files (if available)

Now that you have this information recorded, create the [setup.sh](./setup.sh) script in the ./theta folder and make the script executable:
```
chmod +x ./setup.sh
```

Now, run the [setup.sh](./setup.sh) script in the ./theta folder to 1) auto-create the proper directory structure and b) download and decompress all files. 

The user will be prompted to enter the following information, which will create the necessary folder structure, download all files and decompress them. If the user species does not have one of these listed files, just enter NA when prompted).

For example:

```
./setup.sh

Hello, what is the name of the species genome you are about to download?
GCF_002007445.1_ASM200744v2

Creating directory structure for GCF_002007445.1_ASM200744v2, please confirm that it was created correctly

Please specify the path to the FTP refseq genome:
https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/002/007/445/GCF_002007445.1_ASM200744v2/GCF_002007445.1_ASM200744v2_genomic.fna.gz

Please specify the path to the FTP refseq rm out file:
https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/002/007/445/GCF_002007445.1_ASM200744v2/GCF_002007445.1_ASM200744v2_rm.out.gz

Please specify the path to the FTP refseq annotations:
https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/002/007/445/GCF_002007445.1_ASM200744v2/GCF_002007445.1_ASM200744v2_genomic.gtf.gz

```

Once completed, check the standard out to ensure that all fully downloaded (100%), decompressed, named correctly and are not empty. For example, the user should see something like this printed out on the screen when running the above script:

```
Please confirm that all downloaded files were fully downloaded 100%
 15450K .......... .                                          100%  375M=0.3s
733150K .......... .......... .......... ....                 100%  278M=11s
128950K .....                                                 100%  379M=1.9s
```
And confirm that none of the files are empty (based upon file size) and named accordingly:

```
Are all downloaded files named correctly and are not empty?
GCF_009873245.2_mBalMus1.pri.v3/GCF_009873245.2_mBalMus1.pri.v3_gtf:
total 400M
-rw-r--r-- 1 blackan student 500M Oct 29 03:52 GCF_009873245.2_mBalMus1.pri.v3.gtf

GCF_009873245.2_mBalMus1.pri.v3/GCF_009873245.2_mBalMus1.pri.v3_ref:
total 2.2G
-rw-r--r-- 1 blackan student 2.3G Oct 29 03:52 GCF_009873245.2_mBalMus1.pri.v3.genomic.fna

GCF_009873245.2_mBalMus1.pri.v3/GCF_009873245.2_mBalMus1.pri.v3_rm:
total 464M
-rw-r--r-- 1 blackan student 544M Oct 29 03:52 GCF_009873245.2_mBalMus1.pri.v3.rm.out
```
Finally, the header of the mitochondrial sequence (if present) will be identified and used to remove this sequence from the reference genome. The script will print out information on this step, so please check for any memory issues or error messages:

```
Now, the reference will be searched for a mitochondrion sequence
>NC_001601.1 Balaenoptera musculus mitochondrion, complete genome
 
If a sequence was printed out, this will now be removed from the reference genome
java -ea -Xmx8191m -cp /group/bioinfo/apps/apps/BBMap-37.93/current/ driver.FilterReadsByName include=f in=./GCF_009873245.2_mBalMus1.pri.v3/GCF_009873245.2_mBalMus1.pri.v3_ref/GCF_009873245.2_mBalMus1.pri.v3.genomic.fna out=./GCF_009873245.2_mBalMus1.pri.v3/GCF_009873245.2_mBalMus1.pri.v3_ref/tmp.fasta names=mitochondrion ow=t substring=t
Executing driver.FilterReadsByName [include=f, in=./GCF_009873245.2_mBalMus1.pri.v3/GCF_009873245.2_mBalMus1.pri.v3_ref/GCF_009873245.2_mBalMus1.pri.v3.genomic.fna, out=./GCF_009873245.2_mBalMus1.pri.v3/GCF_009873245.2_mBalMus1.pri.v3_ref/tmp.fasta, names=mitochondrion, ow=t, substring=t]

Input is being processed as unpaired
Time:               9.713 seconds.
Reads Processed:    106 	0.01k reads/sec
Bases Processed:    2374868943 	244.50m bases/sec
Reads Out:          105
Bases Out:          2374852541
```

STEP 2 (*UNTESTED*):

Now that the files have been download and decompressed, the reference needs to be QC'd using the following scripts:

  a) [qc_reference.sh](./qc_reference.sh) & [repeatmasker_names.R](./repeatmasker_names.R)
  
  b) [qc_reference_stats.sh](./qc_reference_stats.sh) & [qc_reference_stats.R](./qc_reference_stats.R)


STEP 3: Locate and download SRA files for population level reads:

Locate SRA files for a given species:
NEEDS TO BE WRITTEN!

Download SRA files. 
We will be downloading SRA files using an interactive session:
```
sinteractive -A standby -t 4:00:00 -n 6
```

Now, make sure the user is in the main directory (i.e., theta)
```
cd /scratch/bell/dewoody/theta
```

The script to download these SRA files need to be run in the above directory (or the main project directory).
The SRA names should be recorded in the following CSV format, e.g.:

```
ERR1843087,ERR1843088,ERR1843089
```
Now, the user is ready to run the [download_sra.sh](./download_sra.sh) script, such as:
```
chmod +x ./download_sra.sh
./download_sra.sh
```
The user will be prompted to paste in the name of the genome assembly, such as:

```
Hello, what is the name of the species genome?
GCF_009873245.2_mBalMus1.pri.v3
```
This will change the working directory to this species download folder.
The user will then be prompted to enter the CSV list of SRA accessions:
```
Please specify the name of the file containing sra names, this should be located in your pwd directory for GCF_009873245.2_mBalMus1.pri.v3
ERR1843087,ERR1843088,ERR1843089
```
This script will then download all SRA files and dump them into paired-end fastq file format.

Now, you should be able to ls and see your brand new fastq files named with the [S,E]RRXXXXX_1.fastq for single end data, and [S,E]RRXXXXX_2.fastq for paired end data. 

Note, make sure that there are no unresolved downloads during either the SRA download or fastq!

#DONE

STEP-4: QC and mapping of SRAs

Now that the population level data has been downloaded and converted to paired-end fastq file format, the next step is to clean the reads of low quality base calls (<Q20) and remove any adapters present in the data (while these would likely be soft masked during the alignment step, best to just remove them here). This will all be accomplished using the trimgalor program, which will auto predict the adapter sequence based upon location and prevelance of nucleotides in the reads.

Copy / move the [cleaning.sh](./cleaning.sh) script to the following path, e.g.:
```
/scratch/bell/dewoody/theta/GCF_009873245.2_mBalMus1.pri.v3/sra/raw
```
And then execute the SLURMM script as a job:

```
sbatch cleaning.sh
```

Once the job is finished, check the output of the slurm job to get a snapshot of the cleaning metrics. 
User should be in the 'raw' directory and run the following command:
```
ls -1 *fastq > tmp.1 ; grep "Total written (filtered):" slurm* > tmp.2 ; paste tmp.1 tmp.2 ; rm tmp.*
```
Which should print out someting like this:

```
ERR1843087.sra_1.fastq	Total written (filtered):     92,177,528 bp (95.8%)
ERR1843087.sra_2.fastq	Total written (filtered):     83,786,746 bp (87.5%)
. . .
```
#DONE

#### pipeline is tested until this step ####




- mapping.sh
- realignment_single.sh (for individuals with a single SRA)
- realignment_multiple.sh (for individuals with multiple SRAs)


QC of bam dataset
- qc_bams.sh & quantile_thresholds.R



Analyses
- angsd.sh



