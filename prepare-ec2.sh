#!/bin/sh

sudo apt update
sudo apt install -y python3-pandas python3-psycopg2 python3-bs4 python3-tqdm python3-sqlalchemy python3-nltk python3-sklearn make

# Then
# python
#   import ntlk
#   nltk.download('punkt')

# Not needed except for the scrape, which is already under control
#sudo apt install python3-selenium
# sudo apt install ghc 

# sudo pvcreate /dev/nvme1n1
# sudo vgcreate /dev/vgdata /dev/nvme1n1
# sudo lvcreate -L 50 /dev/vgdata
# sudo mkfs /dev/vgdata/lvol0

sudo mount /dev/vgdata/lvol0 /mnt
sudo chown ubuntu:ubuntu /mnt

# I think all I need is extract_vocab.py, makefile_generator.py and db.conf, isn't it?
# On my laptop...
# scp extract_vocab.py makefile_generator.py db.conf vocab-extractor:/mnt/

# ./makefile_generator.py

# Maybe think about NUMEXPR_MAX_THREADS=1 or =8 or =64 ?
# make -k -j 64
