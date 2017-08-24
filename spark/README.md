Distributed Source Extractor (Sextractor)
Spark (2.2.0) Version for SLURM

Obtain a sextractor catalog for a  mosaic image.
It supports multiple mosaic images that are processed simultaneously, 
generating a catalog per mosaic image. The job can be submited to a
SLURM based HPC system as following:

sbatch -c 4 --ntasks-per-node 2 -N 2 run_spark.slurm --workdir ./exec ./sextractor.spark.py 

for deploying 4 executors (2 per node) using 4 cores each one of it. Executors workdir can
specified to be in a shared filesystem or locally on each compute node when the --workdir
flag is ommited.

Dependencies:

The run_spark.slurm script depends on the following python modules:
  - python-hostlist 
  - argparse
  - subprocess

The sextractor.spark.py script requires to have sextractor installed on each compute
node used as spark slave and it depends on the following python modules:
  - pyspark  (shipped with spark distribution)
  - pyfits
  - subprocess  

Input mosaic images are not available in this repository, but you can get some real
images from the NOAO archive

Strategy:

As the workflow defined by this script requires to read and write files from all workers,
we use this script from a shared filesystem (lustre, nfs, etc) where input and output 
files are stored, and we extended the spark context in order to change the current working 
directory of each task executed by a executor via decorators. In that way, each time an 
executor wants to execute one of the function provided in the workflow, the current 
temporal directory used by the worker will be changed to the directory where the job was
submitted in order to make available in and out directories as relative paths. 

enjoy
JcM
