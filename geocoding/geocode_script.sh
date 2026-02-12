#!/bin/bash
# Run geocode pipeline
#!/usr/bin/env bash
#SBATCH -p small# <-- change to your partition
#SBATCH -N 1 # number of nodes
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2 # <-- adjust to the CPU core count you want to stress
#SBATCH --time=00:10:00 # adjust to running time
#SBATCH --mem=8000 # 8Gbs of RAM (per CPU)
#SBATCH --exclusive

# load R
module load R-base/4.4.2

# TODO: code to run pipeline (on server)
cd /home/anhptq/dengue-geocoding
/package/R-base/4.4.2/bin/Rscript geocoding/main.R --limit=500  >> geocoding/cron_r.log 2>&1

# example cron job that will run at 4:08 pm daily
# 08 16 * * * [path to Rscript] [path to .R file] >> [path to log file] 2>&1
# 00 10 * * * sbatch /home/anhptq/dengue-geocoding/geocoding/geocode_script.sh

# upload the whole folder to the server
# rsync -av --progress --exclude 'renv/library/' \
# -- exclude 'data/incidence' \
# /Users/anhptq/Desktop/dengue-geocoding \
# anhptq@slurm.oucru.org:/home/anhptq/

# upload the code to the server
# rsync -av --progress \
# /Users/anhptq/Desktop/dengue-geocoding/geocoding/ \
# anhptq@slurm.oucru.org:/home/anhptq/dengue-geocoding/geocoding/

# get the new cache from server back to local device
# rsync -av --progress anhptq@slurm.oucru.org:/home/anhptq/dengue-geocoding/data/cached \
# /Users/anhptq/Desktop/dengue-geocoding/data/cached/from_server

# upload cache fr local to server
# rsync -av --progress --exclude 'from_server/' --exclude 'batch/' \
# /Users/anhptq/Desktop/dengue-geocoding/data/cached/ \
# anhptq@slurm.oucru.org:/home/anhptq/dengue-geocoding/data/cached



