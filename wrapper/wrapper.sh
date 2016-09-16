#!/bin/bash

GFILE=(${gFile})
PFILE=`echo ${PFILE} | sed -e 's/ /, /g'`
PFILE=(${PFILE})
MFILE=(${mFile})
INPUTS="${GFILE[@]:1}, ${PFILE[@]:1}, ${MFILE[@]:1}"
CMDLINEARG="${gFile} ${pFile} ${mFile} ${PHENOS} ${COVS} --outDir output ${mkplots} ${saveinter}"
echo inputs are ${INPUTS}
echo arguments are ${CMDLINEARG}


echo  universe                = docker >> lib/condorSubmitEdit.htc
echo docker_image            =  cyverseuk/gwasser:v1.0.0 >> lib/condorSubmitEdit.htc ######
echo arguments                          = ${CMDLINEARG} >> lib/condorSubmitEdit.htc
echo transfer_input_files = ${INPUTS} >> lib/condorSubmitEdit.htc
echo transfer_output_files = output >> lib/condorSubmitEdit.htc
cat /mnt/data/rosysnake/lib/condorSubmit.htc >> lib/condorSubmitEdit.htc

less lib/condorSubmitEdit.htc

jobid=`condor_submit lib/condorSubmitEdit.htc`
jobid=`echo $jobid | sed -e 's/Sub.*uster //'`
jobid=`echo $jobid | sed -e 's/\.//'`

#echo $jobid

#echo going to monitor job $jobid
condor_tail -f $jobid

exit 0
