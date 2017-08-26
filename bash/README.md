Distributed Source Extractor (sextractor)
Bash version for SLURM

This is the version of distributed sextractor for a list of mosaic images in order
to compute a single catalog for each provided mosaic (all ccds)

There are required several scripts, where the first (splitMosaic) is implemented by using several
approches for implementing a distributed job. All the scripts are only writen in bash and using
basic astronomical software tools such as wcstools and imcopy. 

* Requisites:

- pimcopy (threaded version of imcopy implemented by the CMM)
- imcopy (single threaded version)
- gethead from wcstools
- bashs xargs, find, wc, mktemp, getops

* Threaded version

This version is the simplest one. It uses the pimcopy, a threaded version of imcopy developed
at the CMM for the HiTS pipeline. This implementation uses a thread for extracting a single CCD. So,
when extracting all CCDs contained in a mosaic image, it will use as many thread as CCDs are in the input file.
For a DECam image, we are talking of 64 threads. The threaded extraction uses a unique handler for reading
the mosaic image, so, it is quite efficent in reading the file, and each thread opens a writing fits file
in order to write the extracted ccd. Also this copy several keys from the mosaic image into the CCD header,
thing that the classical imcopy does not do. Note this version write only uncompressed fits, even when
the output files have .fits.fz extension. In a new implementation of pimcopy, it will support compressed and
uncompressed extraction as classical imcopy does. That way this version does not implement the -f and the -c flags
since the overwriting desicion is handler by the pimcopy its self, and compressed ccds files are not yet supported
as mentioned.

sbatch -n1 -c 8 -J "splitmosaic_thr" ./sbin/splitMosaic_threaded.sh -i ./in/tu2208329.fits.fz -o ./output

* Sequential version

This version execute the classical imcopy sequentially on the mosaic image in order to extract all ccds. 
This version does include overwritting of output files and compressed ccds files flags. The execution is 
done by iterating a sequence of index (ccd_num) from 1 to number of CCDS contained in the mosaic image. 
Extra keys from the mosaic's header are not copied into the extracted ccds.

$ sbatch -n 1 -J "splitmosaic_seq" ./sbin/plitMosaic_sequential.sh -i ./in/tu2208329.``fits.fz -o ./output -f -c

* Parallel version (bash forking) 

This version uses xargs for execting in parallel the imcopy command (the same as the previous example), so the extraction is done in parallel using as many (child) processed as CCDs in the mosaic image. The submision example
specify one task with 8 cores in oder to use as much as cores have the compute node (in our case 8) in order to overbook the cores safely (without harm other users using the same node). 

$ sbatch -n 1 -c 8 -J "splitmosaic.par" ./sbin/plitMosaic_parallel.sh -i ./in/tu2208329.``fits.fz -o ./output -f -c

* Distributed version (sbatch + srun)

This version uses srun for executing the imcopy command in the compute nodes allocated by the sbatch command. 
So, the submission command shall specify the number of tasks to be used by jobsteps in order to execute imcopy in one of the allocated cores.

$ sbatch -n 60 -J "splitmosaic" ./bin/plitMosaic_distributed.sh -i in/tu2208329.fits.fz -o output -f -c

Enjoy

JcM
