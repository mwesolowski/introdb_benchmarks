poolSize=25
numberOfThreads=64
meeting_timestamp="2018-12-15 19:00"

detailed_log_file=/dev/null
> $detailed_log_file

git clone https://github.com/symentispl/introdb >> $detailed_log_file 2>&1
logins=$(curl -s https://api.github.com/repos/symentispl/introdb/forks | jq -r '.[].owner.login')

cd introdb

for login in $logins; do
  git remote add $login https://github.com/${login}/introdb >> $detailed_log_file 2>&1
done

git fetch --all >> $detailed_log_file 2>&1

echo "----- numberOfThreads: $numberOfThreads, poolSize: $poolSize -----"

sorted_logins=$(echo -e "$logins" | sort  --ignore-case)
> ../plot_data.txt
for login in $sorted_logins; do
  git checkout ${login}/master >> $detailed_log_file 2>&1
  commit_on_master_at_specified_time=$(git rev-list -n 1 --before="$meeting_timestamp" ${login}/master)
  git checkout $commit_on_master_at_specified_time >> $detailed_log_file 2>&1

  if [ ! -f core/src/main/java/introdb/heap/pool/ObjectPool.java ]; then
    : # echo "$login - ObjectPool.java does not exist"
  else
    cp ../ObjectPoolBenchmark.java perf/src/main/java/introdb/heap/pool/ObjectPoolBenchmark.java
    ./mvnw -q clean package >> $detailed_log_file 2>&1
    if [[ "$?" -ne 0 ]] ; then
      : # echo "$login - build fails, probably tests do not pass"
    else
      echo $login
      result="$(java -jar perf/target/benchmarks.jar -f 1 -t $numberOfThreads -p poolSize=$poolSize introdb.heap.pool.ObjectPoolBenchmark.testPool 2>/dev/null | tail -2)"
      echo "$result"
      last_line=$(echo -e "$result" | tail -n1)
      operations_per_second=$(echo "$last_line" | tr -s ' ' | cut -d' ' -f5)
      echo "$login $operations_per_second" >> ../plot_data.txt
    fi
    git checkout -- .
  fi 
done

cd ..

gnuplot -e "
  set boxwidth 0.5;
  set style fill solid;
  set terminal jpeg;
  set yrange [ 0 : * ];
  set output 'benchmark_threads_${numberOfThreads}_pool_${poolSize}.jpeg';
  plot 'plot_data.txt' using 2:xtic(1) with boxes title 'threads: ${numberOfThreads}, poolSize: ${poolSize}'
"
