#include <jni/jni.hpp>

#include <iostream>

//#define N 2048 * 2048 // Number of elements in each vector

__global__ void cuda_saxpy(int N, float x, float * a, float * b, float * c)
{
  // Determine our unique global thread ID, so we know which element to process
  int tid = blockIdx.x * blockDim.x + threadIdx.x;
  int stride = blockDim.x * gridDim.x;
  
  for (int i = tid; i < N; i += stride)
    c[i] = x * a[i] + b[i];
}


extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*)
   {
    struct CudaCalculator
       {
        static constexpr auto Name() { return "CudaCalculator"; }

        CudaCalculator(JNIEnv&) { std::cout << "CUDA Native peer initialized" << std::endl; }
        CudaCalculator(const CudaCalculator&) = delete; // noncopyable
        ~CudaCalculator() { std::cout << "Native peer finalized" << std::endl; }

        jni::jint saxpy(
            jni::JNIEnv &env, 
            jni::jint N,
            jni::jfloat x,
            jni::Array<jni::jfloat> &ja,
            jni::Array<jni::jfloat> &jb, 
            jni::Array<jni::jfloat> &jc) {
                //jni::jsize na = a.Length(env);
                //jni::jfloat a0 = a.Get(env, 0);
                int deviceId;
                int numberOfSMs;
               
                cudaGetDevice(&deviceId);
                cudaDeviceGetAttribute(&numberOfSMs, cudaDevAttrMultiProcessorCount, deviceId);
                
                float *a, *b, *c;
                int size = N * sizeof (float);
                
                cudaMallocManaged(&a, size);
                cudaMallocManaged(&b, size);
                cudaMallocManaged(&c, size);
                
                for(int i=0; i<N; i++) {
                    a[i] = ja.Get(env, i);
                    b[i] = jb.Get(env, i);
                    c[i] = jc.Get(env, i);
                }
                

                cudaMemPrefetchAsync(a, size, deviceId);
                cudaMemPrefetchAsync(b, size, deviceId);
                cudaMemPrefetchAsync(c, size, deviceId);
            
                int threads_per_block = 256;
                int number_of_blocks = numberOfSMs * 32;
            
                cuda_saxpy <<<number_of_blocks, threads_per_block>>>( N, x, a, b, c );
                cudaDeviceSynchronize(); // Wait for the GPU to finish
                
                // Print out the first and last 5 values of c for a quality check
                for( int i = 0; i < 5; ++i )
                  printf("c[%d] = %f, ", i, c[i]);
                printf ("\n");
                for( int i = N-5; i < N; ++i )
                  printf("c[%d] = %f, ", i, c[i]);
                printf ("\n");
            
                // Free all our allocated memory
                cudaFree( a ); cudaFree( b ); cudaFree( c );
                
                return 0;
            }
       };

    jni::JNIEnv& env { jni::GetEnv(*vm) };

    #define METHOD(MethodPtr, name) jni::MakeNativePeerMethod<decltype(MethodPtr), (MethodPtr)>(name)

    jni::RegisterNativePeer<CudaCalculator>(env, jni::Class<CudaCalculator>::Find(env), "peer",
        jni::MakePeer<CudaCalculator>,
        "initialize",
        "finalize",
        METHOD(&CudaCalculator::saxpy, "saxpy") );

    return jni::Unwrap(jni::jni_version_1_2);
   }
