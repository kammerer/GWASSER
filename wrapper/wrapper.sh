GFILE=(${gFile})
GFILE=${GFILE[@]:1}
PFILE=(${pFile})
PFILE=${PFILE[@]:1}
PFILE=`for el in ${PFILE}; do echo ${el}", "; done`
MFILE=(${mFile})
MFILE=${MFILE[@]:1}

ARGS="${gFile} ${pFile} ${mFile} ${PHENOS} ${COVS} --outDir output ${mkplots} ${saveinter}"
INPUTS=${GFILE}", "${PFILE} ${MFILE}

echo  universe                = docker >> lib/condorSubmitEdit.htc
echo docker_image            =  cyverseuk/gwasser:v1.0.0 >> lib/condorSubmitEdit.htc ######
echo executable               =  ./launch.sh >> lib/condorSubmitEdit.htc #####
echo arguments                          = ${ARGS} >> lib/condorSubmitEdit.htc
echo transfer_input_files = ${INPUTS} launch.sh >> lib/condorSubmitEdit.htc
echo transfer_output_files = output >> lib/condorSubmitEdit.htc
cat lib/condorSubmit.htc >> lib/condorSubmitEdit.htc

less lib/condorSubmitEdit.htc

jobid=`condor_submit lib/condorSubmitEdit.htc`
jobid=`echo $jobid | sed -e 's/Sub.*uster //'`
jobid=`echo $jobid | sed -e 's/\.//'`

#echo $jobid

#echo going to monitor job $jobid
condor_tail -f $jobid

exit 0

