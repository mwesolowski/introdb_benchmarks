package introdb.heap.pool;

import java.io.IOException;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.locks.ReentrantLock;

import org.openjdk.jmh.annotations.*;
import org.openjdk.jmh.infra.Blackhole;

@State(Scope.Benchmark)
public class ObjectPoolBenchmark {

    private ObjectPool<ReentrantLock> pool;

    @Param( {"4","25"})
    public int poolSize;

    @Setup(Level.Iteration)
    public void setUp() throws IOException, ClassNotFoundException {
        pool = new ObjectPool<>(ReentrantLock::new, (ReentrantLock l) -> !l.isLocked(), poolSize);
    }

    @TearDown(Level.Iteration)
    public void tearDown() throws IOException, InterruptedException {
        pool.shutdown();
    }

    @Benchmark
    @Threads(8)
    public void testPool(Blackhole blackhole) throws InterruptedException, ExecutionException {
        CompletableFuture<ReentrantLock> future = pool.borrowObject();
        ReentrantLock lock = future.get();
        try {
            blackhole.consume(lock);
        } finally {
            pool.returnObject(lock);
        }
    }

}

