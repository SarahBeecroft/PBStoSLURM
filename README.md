# Convert PBS/Torque job scripts to Slurm (SBATCH)

Designed for USYD NCI users migrating to Pawsey.
Handles common PBS directives, module loads, and job array syntax.

## Usage:
```bash
   pbs2slurm my_job.pbs                  # prints converted script to stdout
   pbs2slurm my_job.pbs -o my_job.slurm  # writes to file
   pbs2slurm my_job.pbs --in-place       # overwrites original (makes .pbs.bak backup)
   pbs2slurm --cheatsheet                # print PBS ↔ Slurm quick reference
```
Author: auto-generated with Claude Opus 4.6 as a helper for Pawsey onboarding

## Cheatsheet quick reference:
```bash
PBS / Torque  ↔  Slurm  Quick Reference
========================================

DIRECTIVES
----------
#PBS -N jobname              →  #SBATCH --job-name=jobname
#PBS -q normal               →  #SBATCH --partition=work
#PBS -l walltime=HH:MM:SS   →  #SBATCH --time=HH:MM:SS
#PBS -l ncpus=N              →  #SBATCH --ntasks=1 --cpus-per-task=N
#PBS -l mem=XGB              →  #SBATCH --mem=XG
#PBS -l ngpus=N              →  #SBATCH --gres=gpu:N
#PBS -l jobfs=XGB            →  (use $MYSCRATCH or $MYSOFTWARE)
#PBS -l storage=gdata/xx     →  (not needed on Pawsey)
#PBS -l wd                   →  (Slurm defaults to submit dir)
#PBS -P project              →  #SBATCH --account=project
#PBS -o stdout.log           →  #SBATCH --output=stdout.log
#PBS -e stderr.log           →  #SBATCH --error=stderr.log
#PBS -j oe                   →  #SBATCH --output=combined.log
#PBS -M user@email           →  #SBATCH --mail-user=user@email
#PBS -m abe                  →  #SBATCH --mail-type=BEGIN,END,FAIL
#PBS -J 1-100                →  #SBATCH --array=1-100
#PBS -l select=N:...         →  #SBATCH --nodes=N --ntasks-per-node=...
#PBS -W depend=afterok:ID    →  #SBATCH --dependency=afterok:ID

ENVIRONMENT VARIABLES
---------------------
$PBS_JOBID                   →  $SLURM_JOB_ID
$PBS_JOBNAME                 →  $SLURM_JOB_NAME
$PBS_O_WORKDIR               →  $SLURM_SUBMIT_DIR
$PBS_ARRAY_INDEX             →  $SLURM_ARRAY_TASK_ID
$PBS_NCPUS                   →  $SLURM_CPUS_PER_TASK
$PBS_NGPUS                   →  $SLURM_GPUS / $SLURM_GPUS_ON_NODE
$PBS_NODEFILE                →  (srun handles distribution)
$TMPDIR / $PBS_JOBFS         →  $MYSCRATCH  (Pawsey convention)

COMMANDS
--------
qsub script.pbs              →  sbatch script.slurm
qstat                        →  squeue -u $USER
qstat -f JOBID               →  scontrol show job JOBID
qdel JOBID                   →  scancel JOBID
qsub -I                      →  salloc  (then srun --pty bash)
pbsnodes -a                  →  sinfo
nqstat / nqstat_anu          →  squeue --start

PAWSEY-SPECIFIC NOTES
---------------------
- Default partition on Setonix: "work"
- No storage directives needed (unlike NCI's gdata/scratch)
- Slurm defaults to submitting from $PWD (no need for -l wd)
- Use $MYSCRATCH, $MYSOFTWARE, $MYGROUP for Pawsey paths
- Load modules the same way: module load samtools/1.19
- For GPU jobs on Setonix GPU nodes: --partition=gpu --gres=gpu:N --account=pawseyxxxx-gpu
```
