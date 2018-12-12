#!/usr/bin/env python
# Distributed Sextractor for multiple mosaic images
# Spark version 
# updated 10/12/2018
# (c) 2017 - Juan Carlos Maureira - Center for Mathematical Modeling

from __future__ import print_function
from pyspark import SparkContext,SparkConf

from astropy.io import fits
import subprocess
import os

# extends SparkContext to handle the working directory change
# via decorators
class MySparkContext(SparkContext):
    cwd = os.getcwd()

    def __init__(self,*args, **kwargs):
        super(MySparkContext,self).__init__(*args,**kwargs)

    def getApplicationId(self):
        return self.applicationId

    @staticmethod
    def apply(fn,*args, **kwargs):
        curdir=os.getcwd()
        os.chdir(MySparkContext.cwd)
        x = fn(*args, **kwargs)
        os.chdir(curdir)
        return x

# decorator for appling a custom context
# to the execution of tasks (i.e. change current working directory)
def using(context):
    def decorator(fn):
        def apply_ctx(*args, **kwargs):
            return context.apply(fn,*args, **kwargs)
        return apply_ctx
    return decorator

#
# tasks implementations
#
@using(MySparkContext)
def getCCDList(file):
    print("expanding %s" %(file))
    hdulist = None
    try:
        hdulist = fits.open(file)
    except Exception as e:
        raise RuntimeError("error opening %s. exception: %s. pwd %s" % (file,e,os.getcwd()))

    prihdr = hdulist[0].header
    num_ccds = prihdr["NEXTEND"]
    print("Number of CCDs %d" %(num_ccds))
 
    hdu_list = [];
 
    for idx, hdu in enumerate(hdulist):
        name = hdu.name
        keys = list(hdu.header.keys())
        print(idx, name, len(keys))
        if idx != 0:
            hdu_list.append({
                'id':idx, 
                'file':file, 
                'name':hdu.name,
                'header':keys,
                'object':prihdr['OBJECT'],
                'mjd':prihdr['MJD-OBS'],
                'key_num': len(keys)})
 
    hdulist.close()
    return hdu_list

@using(MySparkContext)
def writeCCD(ccd_handler):
    print("writing ccd %s" %(ccd_handler['name']))
    data = fits.getdata(ccd_handler['file'], extname=ccd_handler['name'])
    hdu = fits.ImageHDU(data)

    ccd_file = "out/%s-%s-%s.fits" %(ccd_handler['object'],ccd_handler['name'],ccd_handler['mjd'])

    for card in ccd_handler['header']:
        hdu.header.append(card)

    hdu.writeto(ccd_file,clobber=True) 
    print("ccd %s done" %(ccd_handler['name']))
    ccd_handler["ccd_file"] = ccd_file
    return ccd_handler

@using(MySparkContext)
def runSextractor(ccd_handler):
    print("Running sextractor on %s" %(ccd_handler["ccd_file"]))
    catalog_file="%s.catalog" %(ccd_handler["ccd_file"])
    cmd=["sextractor",ccd_handler["ccd_file"],"-c", "etc/default.sex","-CATALOG_NAME",catalog_file]

    proc=subprocess.Popen(cmd,stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    proc.wait()
    exit_code = proc.returncode 
   
    if (exit_code != 0):
        raise RuntimeError("Error running sextractor to generate %s %d %s" % (catalog_file,exit_code,proc.stderr.read())) 

    ccd_handler["catalog"] = catalog_file
    return ccd_handler

@using(MySparkContext)
def mergeCatalogs(cats):
    print("merging catalogs for %s" % (cats[0]))
    merged_catalog = "out/%s.catalog" % (cats[0])

    if os.path.exists(merged_catalog):
        os.unlink(merged_catalog)

    cmd = "cat "
    for c in cats[1]:
        cmd = "%s %s" %(cmd,c)

    cmd = "%s > %s" %(cmd, merged_catalog)  
    os.system(cmd)

    return merged_catalog

#
# Main routine
#
if __name__ == "__main__":
    print("Distributed Sextractor using spark")

    # configure spark context using our extended context
    conf = SparkConf()
    conf.setAppName("dist-sextractor")
    sc = MySparkContext(conf=conf)

    # reduce logging
    log4j = sc._jvm.org.apache.log4j
    log4j.LogManager.getRootLogger().setLevel(log4j.Level.ERROR)

    # define input files 
    # TODO: get inputs as arguments
    in_files = [ 'in/tu2208329.fits.fz', 'in/tu2214935.fits.fz', 'in/tu2216725.fits.fz' ]

    # Rock & roll
    # obtain the CCD list for all input files
    ccds = sc.parallelize(in_files).flatMap(getCCDList).collect()

    # obtain a list of ccd files 
    fits = sc.parallelize(ccds).map(writeCCD).collect()

    # obtain catalogs per object
    cats_per_object = sc.parallelize(fits).map(runSextractor).map(lambda o: (o['object'], [ o['catalog'] ])).reduceByKey(lambda a,b: a+b ).collect()

    # obtain merged catalog per object
    cat_list = sc.parallelize(cats_per_object).map(mergeCatalogs).collect()

    # show the merged catalog list
    print(cat_list)

    # stop the spark context
    sc.stop()

    # good bye
    print("Done")
