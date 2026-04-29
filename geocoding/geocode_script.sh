#!/bin/bash
# Run geocode pipeline
#!/usr/bin/env bash
#SBATCH -p small# <-- change to your partition
#SBATCH -N 1 # number of nodes
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2 # <-- adjust to the CPU core count you want to stress
#SBATCH --time=04:00:00 # adjust to running time
#SBATCH --mem=10000 # 10Gbs of RAM (per CPU)
#SBATCH --exclusive

# load R
module load R-base/4.4.2

# script to geocode hcm data
cd /home/anhptq/dengue-geocoding
/package/R-base/4.4.2/bin/Rscript geocoding/main.R --limit=10000 --batch=2000 --sleep=20 >> geocoding/cron_r.log 2>&1

# script to geocode BD-VT dat
# cd /home/anhptq/dengue-geocoding
# /package/R-base/4.4.2/bin/Rscript geocoding/main.R \
#     --limit=30000 --batch=2000 --sleep=20 \
#     --to_geocode="./data/cached/to_geocode_bd_vt_df.qs" \
#     --cache="./data/cached/geocoded_bd_vt_df.qs" \
#     --cache_failed="./data/cached/failed_geocoded_bd_vt_df.qs" \
#     --generate_to_geo="./codes/02_generate_to_geocode_bd_vt.R" \
#     >> geocoding/cron_r.log 2>&1

# script to geocode address after the merge in August 2025
# cd /home/anhptq/dengue-geocoding
# /package/R-base/4.4.2/bin/Rscript geocoding/main.R \
#     --limit=1 --batch=1 --sleep=20 \
#     --to_geocode="./data/cached/to_geocode_aug2025.qs" \
#     --cache="./data/cached/geocoded_aug2025_df.qs" \
#     --cache_failed="./data/cached/failed_geocoded_aug2025_df.qs" \
#     --generate_to_geo="./codes/05_generate_to_geocode_aug2025.R" \
#     >> geocoding/cron_r.log 2>&1


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

# upload to_geocode_df.qs fr local to server
# rsync -av --progress /Users/anhptq/Desktop/dengue-geocoding/data/cached/to_geocode_df.qs  \
# anhptq@slurm.oucru.org:/home/anhptq/dengue-geocoding/data/cached/to_geocode_df.qs


