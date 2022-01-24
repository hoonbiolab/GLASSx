#!/bin/sh
#SBATCH --cpus-per-task=12 
#SBATCH --time 8:00:00
#SBATCH --mem=36g
#SBATCH --output /projects/verhaak-lab/GLASS-III/logs/slurm/CIBERSORTx_HiRes_neftel.out
#SBATCH --error /projects/verhaak-lab/GLASS-III/logs/slurm/CIBERSORTx_HiRes_neftel.err

#sbatch cibersortx_hires_run_neftel_freeze_rev.sh --job-name cibersortx_hires
#srun -q batch -N 1 --cpus-per-task=12 --mem 36G -t 8:00:00 --pty bash 

module load singularity

singularity exec \
-B /projects/verhaak-lab/GLASS-III/data/cibersortx/glass_20210923/:/src/data \
-B /projects/verhaak-lab/GLASS-III/results/cibersortx/hires/GLASS_neftel_freeze/:/src/outdir \
/projects/verhaak-lab/varnf/docker/CIBERSORTx/hires_latest.sif "/src/CIBERSORTxHiRes" \
--username Frederick.S.Varn.Jr.GR@dartmouth.edu \
--token  ef745da3ebf38e86c4b115ea37df2362 \
--mixture gene_tpm_matrix_all_samples.tsv \
--sigmatrix neftel_cibersortx_sig_08032020.txt \
--label 'GLASS' \
--rmbatchBmode TRUE \
--groundtruth klemm_purified_avg_ground_truth_cpm_neftel.txt \
--subsetgenes neftel_common_genes.txt \
--sourceGEPs neftel_cibersortx_cell_type_sourceGEP_08032020.txt \
--threads 12 \
--cluster  true 