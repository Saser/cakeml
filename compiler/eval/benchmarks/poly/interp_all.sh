TIMEFORMAT=%R
for benchmark in *.sml; do
  echo smlnj_$benchmark
  for i in `seq 30`
  do
    time (sed '2d;1d;$d' $benchmark | sml @SMLalloc=100000k > dump)
  done
done
rm dump
for benchmark in *.sml; do
  echo poly_$benchmark
  for i in `seq 30`
  do
    time (sed '2d;1d;$d' $benchmark | poly > dump)
  done
done
rm dump
for benchmark in *.sml; do
  echo cake_$benchmark
  for i in `seq 30`
  do
    time (sed '2d;1d;$d' $benchmark | ./cake > dump)
  done
done
rm dump
