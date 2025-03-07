#!/bin/bash
# author : sjn
# date : Aug 25, 2022

# Histogram of per read length/#nucleosomes (bin sz=1, range 0-2000bp)
#  Collapse all reads > 2000 to 2000
#  Vertical line at median value between 0-300 bp/nuc
# Can you actually make this with xlim 0-1500, and say on the chart the % of fibers in the bin >1500
# Get % reads with readlength/#nucs < 300 and put in stats file

set -euo pipefail

if [[ $# != 4 ]]; then
    printf "Expect $0 <sample-name> <input-file> <output-pdf> <output-stat.txt>\n"
    exit 1
fi

samplenm=$1
inp=$2 # fiber-all-table.tbl.gz
outpdf=$3
outstat=$4

ftype=readlength.div.number.nucleosomes
tmpd=/tmp/$(whoami)/$$

if [[ ! -s $inp ]]; then
    printf "Problem finding 1 file: %s\n" $inp
    exit 1
fi

if [[ -s $tmpd ]]; then
    rm -rf $tmpd
fi
mkdir -p $tmpd
mkdir -p $(dirname "${outpdf}")

hck -F fiber_length -F nuc_starts -z $inp |
    awk 'NR > 1' |
    awk '$1 != "."' |
    rev |
    sed 's;,;;' |
    rev |
    awk '{ lng=gsub(/,/, "", $2); if ( lng > 1 ) { print int($1/lng) } }' \
        >$tmpd/$samplenm.$ftype

R --no-save --quiet <<__R__
  library(scales)
  ss <- scan("$tmpd/$samplenm.$ftype")
  mxh <- 1500
  s <- ss
  mxv <- 300
  nlarge <- length(s[s>mxh])
  s[s>mxh] <- mxh
  m <- median(s[s<=mxv])
  plarge <- nlarge/length(s)

  stats_file <- "$outstat"
  prop = round(100*length(s[s<=mxv])/length(s), 1)
  cat("# Note: ***Read length divided by #nucs stats***\n", file=stats_file, append=FALSE)
  cat("Proportion(ReadLength/#nucs<=", mxv, ")=", prop, "%\n", file=stats_file, sep="", append=TRUE)
  cat("Median(ReadLength/#nucs<=", mxv, ")=", m, "\n", file=stats_file, sep="", append=TRUE)

  mycol <- "darkgreen"
  pdf("$outpdf")
  h <- hist(s, xlim=c(0, mxh), breaks=1000, axes=F, main=paste("$samplenm"), xlab="Read Length (bp)/# nucleosome footprints per read", ylab="Count")
  mxc <- max(h[["counts"]][h[["breaks"]]<=mxv])
  rect(0, 0, mxv, max(h[["counts"]]/2), col=alpha(mycol, 0.25), border=NA)
  # plot again to put rect in background
  h <- hist(s, xlim=c(0, mxh), breaks=1000, axes=F, main=paste("$samplenm"), xlab="Read Length (bp)/# nucleosome footprints per read", ylab="Count", add=T)
  #abline(v=mxv, col=alpha(mycol, 0.25), lty=2, lwd=3)
  #abline(v=0, col=alpha(mycol, 0.25), lty=2, lwd=3)
  abline(v=m, col=mycol, lty=1)
  msg <- paste(m)
  msg2 <- paste(round(plarge*100,1), "% >", mxh, "bp", sep="")

  xv <- 75
  offxv <- 8
  rtoff <- 300
  div <- 3
  lines(c(m+rtoff, m), c(max(h[["counts"]])/(div*1.05), 0), col=mycol)
  text(m+rtoff+3*offxv, max(h[["counts"]])/div, msg, col=mycol)
  text(0.85*mxh, max(h[["counts"]])/div, msg2, col=mycol)

  axis(1, seq(0, mxh, 100))
  axis(2)

  dev.off()
__R__

rm -rf $tmpd

exit 0
