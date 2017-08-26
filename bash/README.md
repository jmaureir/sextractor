Distributed Source Extractor (sextractor)
Bash version for SLURM


* Threaded version

sbatch -n1 -c 8 -J "splitmosaic_thr" ./sbin/splitMosaic_threaded.sh -i ./in/tu2208329.fits.fz -o ./output

* Sequential version

$ sbatch -n 1 -J "splitmosaic_seq" ./sbin/plitMosaic_sequential.sh -i ./in/tu2208329.``fits.fz -o ./output -f -c

* Parallel version (bash forking) 

$ sbatch -n 1 -c 8 -J "splitmosaic.par" ./sbin/plitMosaic_parallel.sh -i ./in/tu2208329.``fits.fz -o ./output -f -c

* Distributed version (sbatch + srun)

$ sbatch -n 60 -J "splitmosaic" ./bin/plitMosaic_distributed.sh -i in/tu2208329.fits.fz -o output -f -c
