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
