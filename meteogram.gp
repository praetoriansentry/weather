#!/usr/bin/env gnuplot
# Invoked with -e vars: term_name, outfile, datafile, t_start, t_end, day_label, location_label

if (term_name eq 'pngcairo') {
    set terminal pngcairo size 2400,2800 enhanced font "sans,20" background rgb "white"
} else {
    set terminal svg size 1200,1400 enhanced font "sans,10" background rgb "white"
}
set output outfile

set datafile separator "\t"
set datafile missing ""

set xdata time
set timefmt "%Y-%m-%dT%H:%M:%S"
set xrange [t_start:t_end]
set format x "%l%p"
set xtics 10800 rotate by 0 font "sans,8"
set mxtics 3
set grid xtics ytics mxtics lc rgb "#dddddd" lt 1

set key top right box lc rgb "#888888" samplen 2 spacing 1.1 font "sans,8"

set style line 1 lc rgb "#d62728" lw 2 pt 7 ps 0.5  # red
set style line 2 lc rgb "#2ca02c" lw 2 pt 7 ps 0.5  # green
set style line 3 lc rgb "#ff7f0e" lw 2 pt 7 ps 0.5  # orange
set style line 4 lc rgb "#e377c2" lw 2 pt 7 ps 0.5  # pink
set style line 5 lc rgb "#1f77b4" lw 2 pt 7 ps 0.5  # blue
set style line 6 lc rgb "#bcbd22" lw 2 pt 7 ps 0.5  # yellow-green

set multiplot layout 5,1 title sprintf("NWS Meteogram — %s — %s", location_label, day_label) font "sans,12"

set lmargin 10
set rmargin 4

set ylabel "°F"
set yrange [*:*]
set title "Temperature / Dewpoint / Heat Index"
plot \
    datafile using 1:2 with linespoints ls 1 title "Temperature", \
    datafile using 1:3 with linespoints ls 2 title "Dewpoint", \
    datafile using 1:4 with linespoints ls 3 title "Heat Index"

set ylabel "mph"
set yrange [0:*]
set title "Surface Wind / Gusts"
plot \
    datafile using 1:5 with linespoints ls 4 title "Surface Wind", \
    datafile using 1:6 with linespoints ls 5 title "Gust"

set ylabel "%"
set yrange [0:100]
set title "Relative Humidity / Precip Probability / Sky Cover"
plot \
    datafile using 1:9  with linespoints ls 2 title "Humidity", \
    datafile using 1:10 with linespoints ls 5 title "Precip Prob", \
    datafile using 1:8  with linespoints ls 6 title "Sky Cover"

set ylabel "inches"
set yrange [0:*]
set title "Hourly Rainfall (QPF)"
set style fill solid 0.8 border lc rgb "#1b5e20"
set boxwidth 3000 absolute
plot \
    datafile using 1:11 with boxes lc rgb "#2ca02c" notitle

set ylabel "level"
set yrange [0:4.5]
set ytics ("none" 0, "SChc" 1, "Chc" 2, "Lkly" 3, "Ocnl" 4)
set title "Thunderstorm Coverage"
set style fill solid 0.8 border lc rgb "#7f1111"
plot \
    datafile using 1:12 with boxes lc rgb "#d62728" notitle

unset multiplot
set output
