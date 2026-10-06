#!/usr/bin/env Rscript
# Synthetic combined-schema fixture; does not stand in for MATLAB export tests.
script <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value=TRUE)[1])
repo <- normalizePath(file.path(dirname(script), '..'))
source(file.path(repo, 'analysis/R/io.R'))
source(file.path(repo, 'analysis/R/simulate_demo_data.R'))
root <- tempfile('block-export-io-'); dir.create(root)
on.exit <- NULL
simulate_battery(root, 2)
files <- find_run_files(root)
for (file in files$path) {
  x <- read_run_csv(file)
  x$checkpoint_schema <- 1L; x$complete <- TRUE
  x$attempt_id <- 'synthetic-attempt'
  x$source_file <- NULL
  write_csv(x,file)
}
dir.create(file.path(root,'blocks','raw','cont_dc'),recursive=TRUE)
dir.create(file.path(root,'partial','cont_dc'),recursive=TRUE)
file.copy(files$path[1],file.path(root,'blocks','raw','cont_dc','fragment.csv'))
file.copy(files$path[1],file.path(root,'partial','cont_dc','incomplete.csv'))
stopifnot(nrow(find_run_files(root)) == 4, nrow(load_contdc(root)) == 360,
          nrow(load_auction(root)) == 50)
cmd <- file.path(repo,'analysis/R/00_participant_qc.R')
out <- system2('Rscript',c(shQuote(cmd),'--data',shQuote(root),'--out',shQuote(file.path(root,'qc'))),stdout=TRUE,stderr=TRUE)
status <- attr(out,'status'); if (!is.null(status) && status != 0) stop(paste(out,collapse='\n'))
file.copy(files$path[1], file.path(dirname(files$path[1]),'duplicate.csv'))
err <- tryCatch({load_auction(root); NULL},error=function(e)e)
stopifnot(inherits(err,'error'), grepl('Duplicate run',conditionMessage(err)))
unlink(root,recursive=TRUE)
cat('Combined-schema fixture: 360 contdc + 50 auction rows; raw/partial fragments excluded; duplicate run rejected; participant QC passed.\n')
