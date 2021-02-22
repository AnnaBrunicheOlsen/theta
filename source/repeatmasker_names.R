#install.packages("dplyr", lib="/scratch/bell/dewoody/rlibs/", repos='http://cran.us.r-project.org')
.libPaths("/scratch/bell/dewoody/rlibs/") 
library(dplyr)

pwd = commandArgs(trailingOnly=TRUE)[2]
print(pwd)
setwd(pwd)

#change scaffold names in repeatmasker file to match updated assembly names

#################
# change scaffold names repeatmasker
#################

# read data and name files
df <- read.table("rm.body", header = F)
colnames(df) = c('a','b','c','d','ID','e','f','g','h','i','j','k','l','m','n')

df.name <- read.table("ID.txt", header =F)
colnames(df.name) = c('ID','scaffold')

# find replace ID with scaffold name
df1 <- merge(df, df.name, by = "ID") 
df1$ID <- df1$name

# change order of columns
df2 <- df1[c('a','b','c','d','scaffold','e','f','g','h','i','j','k','l','m','n')]

write.table(df2, file = "rm_edited.body", sep = "\t",row.names = F, col.names = F)

# END
