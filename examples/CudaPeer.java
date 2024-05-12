class CudaCalculator {
    public CudaCalculator() {
        initialize();
    }

    private long peer;
    protected native void initialize();
    protected native void finalize() throws Throwable;

    public native int saxpy(int N, float x, float[] a, float[] b, float[] c);
}

public class CudaPeer {
    public static void main(String[] args) {
        System.loadLibrary("cudapeer");

        CudaCalculator calculator = new CudaCalculator();
        
        int N = 2048;
        float a[] = new float[N];
        float b[] = new float[N];
        float c[] = new float[N];
        float x = 2.0f;
        
        for(int i=0; i<N; i++) {
            a[i] = 2;
            b[i] = 1;
            c[i] = 0;
        }
        calculator.saxpy(N, x, a, b, c);


        // You wouldn't normally use this; it's here to show that the native finalizer does get executed.
        //System.runFinalizersOnExit(true);
    }
}
