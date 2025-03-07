#!/bin/bash -efx
# author : sjn
# date : Aug 22, 2022

set -euo pipefail

if [[ $# != 4 ]]; then
    printf "Expect $0 <sample-name> <input-file> <output-pdf> <output-stat.txt>\n"
    exit 1
fi

samplenm=$1
inp=$2 # fiber-all-table.tbl.gz
outpdf=$3
outstat=$4

ftype=rq
tmpd=/tmp/$(whoami)/$$

if [ -s $tmpd ]; then
    rm -rf $tmpd
fi
mkdir -p $tmpd
mkdir -p $(dirname "${outpdf}")

if [ ! -s $inp ]; then
    printf "Problem finding 1 file: %s\n"
    exit 1
fi

hck -F rq -z $inp |
    awk '(NR>1)' \
        >$tmpd/$samplenm.$ftype

R --no-save --quiet <<__R__
  # 0.0 <= quantile <= 1.0
  fast_kth <- function(array_2d, lower_b, upper_b, quantile) {
    reads <- subset(array_2d, V1>=lower_b & V1<=upper_b)
    sn <- sum(reads[,2])
    marker <- round(sn * quantile, 0)
    i <- 1
    cntr <- 0
    repeat {
      cntr <- cntr + reads[i,2]
      if ( cntr >= marker ) {
        break
      }
      i <- i + 1
    }
    marker <- reads[i,1]
    return(marker)
  }

  mnh <- 0.99
  QV50 <- 0.99999
  s <- scan("$tmpd/$samplenm.$ftype")
  p <- 100*length(s[s<mnh])/length(s)

  count <- length(s[s>QV50])
  all <- length(s)
  perc <- round(100*count/all, 2)
  s[s>=QV50] <- QV50
  s <- 10*(-log10(1-s))

  m <- median(s)

  mycol <- "darkgreen"
  pdf("$outpdf")
  h <- hist(s, axes=F, main=paste("$samplenm", "$ftype", sep=":"), xlab="Log read quality score of each CCS read", ylab="Count", breaks=1000)
  abline(v=m, col=mycol, lty=1)

  rtoff <- 0.001/2
  msg <- paste(perc, "%>QV50", sep="")
  text(0.9*max(s), max(h[["counts"]])/1.5, msg, col=mycol)
  text(m-rtoff, max(h[["counts"]])/1.2, round(m, 1), col=mycol)

  axis(1)
  axis(2)

  dev.off()

  stats_file <- "$outstat"
  cat("# Note: ***read quality stats***\n", file=stats_file, sep="", append=FALSE)
  cat("Median(-10*log10(1-rq))=", m, "\n", file=stats_file, sep="", append=TRUE)
__R__

rm -rf $tmpd

exit 0
