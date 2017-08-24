#!/usr/bin/env python
# SPARK execution script via SLURM
#
# Deploy master and slaves according
# resources allocated by slurm 
# 
# (c) 2016 - 2017 - Juan Carlos Maureira
# (c) 2016 - 2017 - Center for Mathematical Modelling

from __future__ import print_function
import os
import sys
import hostlist
import platform
import subprocess
import time
import threading
import argparse

# Spark environment variables 
class SparkEnvironment(object):
    master_start_cmd            = "/sbin/start-master.sh"
    slave_start_cmd             = "/sbin/start-slave.sh"
    submit_cmd                  = "/bin/spark-submit"

    nodes                       = []
    master_node                 = None
    master_port                 = 7077

    spark_home                  = os.getenv("SPARK_HOME",None)
    slurm_job_nodelist          = os.getenv("SLURM_JOB_NODELIST",None)
    slurm_node_num              = os.getenv("SLURM_JOB_NUM_NODES",1)
    slurm_num_tasks_per_node    = os.getenv("SLURM_NTASKS_PER_NODE",1)
    slrum_cpu_per_task          = os.getenv("SLURM_CPUS_PER_TASK",1)

    def __init__(self,opts = None):

        if self.spark_home == None:
            raise RuntimeError("No SPARK_HOME found") 

        if self.slurm_job_nodelist is not None:
            self.nodes = hostlist.expand_hostlist(self.slurm_job_nodelist)
        else:
            raise RuntimeError("no worker nodes allocated by slrum")

        if len(self.nodes) == 0:
            raise RuntimeError("No workers nodes found") 

    def getMasterStartCommand(self):
        return "%s/%s" % (self.spark_home,self.master_start_cmd)

    def getSlaveStartCommand(self):
        return "%s/%s" % (self.spark_home,self.slave_start_cmd)

    def getSubmitCommand(self):
        return "%s/%s" % (self.spark_home,self.submit_cmd)

    def setMasterNode(self,node):
        self.master_node = node

    def getMasterNode(self):
        return self.master_node

    def getNodes(self):
        return self.nodes

    def getWorkerPerNode(self):
        return self.slurm_num_tasks_per_node

    def getCoresPerWorker(self):
        return self.slrum_cpu_per_task

# Spark master controller
class SparkMaster(SparkEnvironment,threading.Thread):
    cmd          = []
    proc_handler = None
    running      = False
    exit_code    = 0    
    lock         = threading.Lock()

    def __init__(self,args = None):
        SparkEnvironment.__init__(self)
        threading.Thread.__init__(self)

        self.setMasterNode(platform.node())
        self.proc_handler = None

        self.cmd=[self.getMasterStartCommand(),] 
        if isinstance(args,list):
            self.cmd = self.cmd + args

        self.lock.acquire()

    def stop(self):
        self.proc_handler.terminate()

    def isRunning(self):
        with self.lock:
            return self.running

    def createNewWorker(self, node, srun_args=None, worker_args = None):
        worker = SparkSlave(self,node,srun_args,worker_args)
        return worker

    def run(self):
        os.environ["SPARK_NO_DAEMONIZE"] = "true"
        self.proc_handler = subprocess.Popen(self.cmd,stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.running = True
        self.lock.release()
        ret_code = self.proc_handler.wait()
        self.running = False
        self.exit_code = ret_code
   
# Spark slave controller
class SparkSlave(SparkEnvironment,threading.Thread):
    cmd          = []
    proc_handler = None
    running      = False
    exit_code    = 0    
    stderr       = ""
    stdout       = ""
    lock         = threading.Lock()

    def __init__(self,master,node, srun_args = None, worker_args = None):
        SparkEnvironment.__init__(self)
        threading.Thread.__init__(self)
        self.worker_node  = platform.node()
        self.proc_handler = None
        self.worker_node  = node
        self.setMasterNode(master.getMasterNode())
 
        if node not in self.getNodes():
            raise RuntimeError("worker node not listed in nodes allocated by scheduler")

        self.cmd=["srun","--exclusive","-w",self.worker_node,"","-n", self.getWorkerPerNode(),"-c",self.getCoresPerWorker(),"-J","SparkWorker"]

        if isinstance(srun_args,list):
            self.cmd = self.cmd + srun_args

        worker_cmd = [self.getSlaveStartCommand(), "--cores", self.getCoresPerWorker() ] 
        if isinstance(worker_args,list):
            worker_cmd = worker_cmd + worker_args
        worker_cmd.append("spark://%s:%d" % (self.getMasterNode(),self.master_port))

        self.cmd = self.cmd + worker_cmd

        self.lock.acquire()

    def stop(self):
        self.proc_handler.terminate()

    def setWorkDir(self,path):
        self.workdir = os.path.abspath(path)

    def isRunning(self):
        with self.lock:
            return self.running

    def run(self):
        os.environ["SPARK_NO_DAEMONIZE"] = "true"
        self.proc_handler = subprocess.Popen(" ".join(self.cmd),stdout=subprocess.PIPE, stderr=subprocess.PIPE,shell=True)
        self.running = True
        self.lock.release()
        ret_code = self.proc_handler.wait()
        self.exit_code = ret_code

        self.running = False
        if ret_code!=0:
            self.stderr = self.proc_handler.stderr.read()
            self.stdout = self.proc_handler.stdout.read()

    def getError(self):
        return self.stderr

    def getOutput(self):
        return self.stdout

#
# Main Routine
#
if __name__ == "__main__":
    print("Spark execution script")
    print("(c) 2016 - 2017 - Juan Carlos Maureira / Center for Mathematical Modelling")

    # parse arguments
    arg_parser = argparse.ArgumentParser()
    arg_parser.add_argument('-w', '--workdir', help="spark workdir for executors")
    arg_parser.add_argument('spark_script', nargs=argparse.REMAINDER)
    args = arg_parser.parse_args()

    # deploy spark master process
    master_node = platform.node()
    print("Deploing master at %s " % master_node)
    master = SparkMaster()
    master.start()
 
    if (master.isRunning() is False):
        raise RuntimeError("could not deploy master")

    # deploy workers
    workers = []
    try:
        worker_nodes = master.getNodes()
        for worker_node in worker_nodes:
            worker_args = []

            print("deploying worker at %s " % worker_node)
            workdir=None
            if args.workdir is not None:
                workdir = args.workdir
                worker_args.append("--work-dir")
                worker_args.append(workdir)

            w = master.createNewWorker(worker_node,worker_args=worker_args)
            w.start()
            workers.append(w)

        # check the worker status
        for w in workers:
            if w.isRunning() == False:
                master.stop()
                raise RuntimeError("could not start worker: %s : %s " % (w.worker_node,w.getError()))
            else:
                print("worker %s ready" % w.worker_node)
    except:
        raise

    sys.stdout.flush()
    # ready to work!!!
    # submit the python script to master spark process
    try:
        cmd = [master.getSubmitCommand(),"--master", "spark://%s:%d" % (master.getMasterNode(), master.master_port) ]

        cmd = cmd + args.spark_script

        print("submitting spark job")

        spark_job = subprocess.Popen(" ".join(cmd), shell=True, stdout=subprocess.PIPE,)
 
        while spark_job.poll() == None:
            print(spark_job.stdout.readline())
            sys.stdout.flush()
            time.sleep(1)

        ret_code = spark_job.poll()

        print("Exit code: %d" % ret_code)
    except Exception as e:
        print("Execution error: %s" % e)

    # stopping master and slaves
    master.stop()
    for worker in workers:
        worker.stop()

    print("done")
 
