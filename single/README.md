Single CCD Source Extractor (Sextractor)

Bash version
(c) 2014-2017 Juan Carlos Maureira & Francisco Forster
Center for Mathematical Modelling

Obtain a sextractor catalog from a single image. 

How to use this example:

Put all the images in the same directory and try first running e.g. 

sex in/Blind_03_N4_01.fits.fz_proj.fits -CATALOG_NAME test.cat  -WEIGHT_IMAGE in/Blind_03_N4_01_wtmap.fits.fz_proj.fits

to read the image Blind_03_N4_01.fits.fz_proj.fits with the noise map Blind_03_N4_01_wtmap.fits.fz_proj.fits and create a catalogue of stars in the file test.cat 

Then try diff test.cat Blind_03_N4_01_wtmap.fits.fz_proj.fit-catalogue.dat

to test for catalogue differences with the file Blind_03_N4_01_wtmap.fits.fz_proj.fit-catalogue.dat, which was obtained running

sex Blind_03_N4_01.fits.fz_proj.fits  -CATALOG_NAME Blind_03_N4_01_wtmap.fits.fz_proj.fit-catalogue.dat  -WEIGHT_IMAGE Blind_03_N4_01_wtmap.fits.fz_proj.fits

You can submit this script to a HPC system as following:

SLURM: sbatch -n 1 ./run-sextractor.slurm in/Blind_03_N1_01.fits.fz_proj.fits in/Blind_03_N1_01_wtmap.fits.fz_proj.fits 

SGE: qsub ./run-sextractor.slurm in/Blind_03_N1_01.fits.fz_proj.fits in/Blind_03_N1_01_wtmap.fits.fz_proj.fits 

