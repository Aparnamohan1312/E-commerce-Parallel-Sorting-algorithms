#include <iostream>
#include <vector>
#include <ctime>
#include <algorithm>
#include <cuda_runtime.h>
#include "csv.h"
#include <sys/time.h>
#include <fstream>
#include <sstream>

struct Order {
    std::string orderId;
    std::string date;
    std::string state;
};

typedef struct {
    struct timeval startTime;
    struct timeval endTime;
} Timer;

void startTime(Timer* timer) {
    gettimeofday(&(timer->startTime), NULL);
}

void stopTime(Timer* timer) {
    gettimeofday(&(timer->endTime), NULL);
}

float elapsedTime(Timer timer) {
    return ((float) ((timer.endTime.tv_sec - timer.startTime.tv_sec) \
                + (timer.endTime.tv_usec - timer.startTime.tv_usec)/1.0e6));
}

__device__ void merge(int *arr, int *temp, int start, int middle, int end) {
    int i = start, j = middle, k = start;

    while (i < middle && j < end) {
        if (arr[i] < arr[j]) {
            temp[k++] = arr[i++];
        } else {
            temp[k++] = arr[j++];
        }
    }
    __syncthreads();

    while (i < middle) temp[k++] = arr[i++];
    __syncthreads();
    while (j < end) temp[k++] = arr[j++];
    __syncthreads();
    for (i = start; i < end; i++) {
        arr[i] = temp[i];
    }
    __syncthreads();
}

__global__ void mergeSortKernel(int *arr, int *temp, int n, int width) {
    int thIdx = threadIdx.x + blockIdx.x * blockDim.x;
    int start = thIdx * width * 2;

    if (start < n) {
        int middle = min(start + width, n);
        int end = min(start + 2 * width, n);
        merge(arr, temp, start, middle, end);

    }
}

__device__ int partition(int *arr, int left, int right) {
    int pivot = arr[right];
    int i = (left - 1);

    for (int j = left; j <= right - 1; j++) {
        if (arr[j] < pivot) {
            i++;
            int temp = arr[i];
            arr[i] = arr[j];
            arr[j] = temp;
        }
    }

    int temp = arr[i + 1];
    arr[i + 1] = arr[right];
    arr[right] = temp;

    return (i + 1);
}

__global__ void quickSortKernel(int *arr, int left, int right) {
    if (left < right) {
        int pi = partition(arr, left, right);

        quickSortKernel<<<1, 1>>>(arr, left, pi - 1);
        quickSortKernel<<<1, 1>>>(arr, pi + 1, right);
    }
}

__global__ void bitonicSortGPU(int *arr, int n, int k, int j) {
    unsigned int idx = threadIdx.x + blockDim.x * blockIdx.x;
    unsigned int ij = idx ^ j;

    if (idx < n && ij > idx) {
        if ((idx & k) == 0) {
            if (arr[idx] > arr[ij]) {
                int temp = arr[idx];
                arr[idx] = arr[ij];
                arr[ij] = temp;
            }
        } else {
            if (arr[idx] < arr[ij]) {
                int temp = arr[idx];
                arr[idx] = arr[ij];
                arr[ij] = temp;
            }
        }
    }
}

__global__ void radixSortGPU(int *arr, int *output, int n, int exp) {
    int index = blockIdx.x * blockDim.x + threadIdx.x;
    if (index >= n) return;

    int count[10] = {0};

    for (int i = 0; i < n; i++) {
        count[(arr[i] / exp) % 10]++;
    }
    __syncthreads();

    for (int i = 1; i < 10; i++) {
        count[i] += count[i - 1];
    }
    __syncthreads();

    for (int i = n - 1; i >= 0; i--) {
        output[count[(arr[i] / exp) % 10] - 1] = arr[i];
        count[(arr[i] / exp) % 10]--;
    }
    __syncthreads();
    for (int i = 0; i < n; i++) {
        arr[i] = output[i];
    }
}

int main() {

    int arraySize;
    std::cout << "Select an input array size from below: " << "\n";
    std::cout << "1024" << "\n";
    std::cout << "16384" << "\n";
    std::cout << "131072" << "\n";
    std::cin >> arraySize;

    int inputSize;

    std::string filePath = std::to_string(arraySize) + ".csv";


    std::ifstream file(filePath);

    if (!file.is_open()) {
        std::cerr << "Error opening file" << std::endl;
        return 1;
    }

    std::string line;
    std::getline(file, line);
    std::istringstream s(line);
    std::string field;
    std::vector<int> tempDates;

    while (getline(s, field, ',')) {
        tempDates.push_back(std::stoi(field));
    }

    file.close();

    int dates[tempDates.size()];
    for (size_t i = 0; i < tempDates.size(); ++i) {
        dates[i] = tempDates[i];
    }

    inputSize = tempDates.size();

    int n = inputSize;

    Timer timer;

    cudaError_t error_Status;

    int *d_dates, *out_dates;
    error_Status = cudaMalloc((void **)&d_dates, n * sizeof(int));
    if (error_Status != cudaSuccess) {
        std::cout << "cudaMalloc(d_dates) error" << "\n";
    }
    error_Status = cudaMalloc((void **)&out_dates, n * sizeof(int));
    if (error_Status != cudaSuccess) {
        std::cout << "cudaMalloc(out_dates) error" << "\n";
    }

    error_Status = cudaMemcpy(d_dates, dates, n * sizeof(int), cudaMemcpyHostToDevice);
    if (error_Status != cudaSuccess) {
        std::cout << "cudaMemcpy error" << "\n";
    }

    int threadsPerBlock = 32;

    int numBlocks = (n + threadsPerBlock - 1) / threadsPerBlock;

    // input from the USER (1. Merge, 2. Radix )
    int choice;
    std::cout << "Select an option from below: " << "\n";
    std::cout << "1. Merge Sort" << "\n";
    std::cout << "2. Quick Sort" << "\n";
    std::cout << "3. Bitnoic Sort" << "\n";
    std::cout << "4. Radix Sort" << "\n";

    std::cin >> choice;

    switch(choice) {
        case 1:
        {
            startTime(&timer);

            for (int width = 1; width < n; width *= 2) {
                mergeSortKernel<<<numBlocks, threadsPerBlock>>>(d_dates, out_dates, n, width);
                cudaDeviceSynchronize();
            }

            stopTime(&timer);
            
            std::cout << "Merge Sort: <INPUT SIZE: " << n << "> and <THREADS/BLOCK: " << threadsPerBlock << ">" << "\n" << "Elapsed time: " << elapsedTime(timer) << " sec\n";
            break;
        }

        case 2:
        {
            startTime(&timer);
            quickSortKernel<<<1, 1>>>(d_dates, 0, n - 1);
            cudaDeviceSynchronize();
            stopTime(&timer);
            std::cout << "Quick Sort: <INPUT SIZE: " << n << "> and <THREADS/BLOCK: " << threadsPerBlock << ">" << "\n" << "Elapsed time: " << elapsedTime(timer) << " sec\n";
            break;
        }
            

        case 3:
        {
            startTime(&timer);
            for (int k = 2; k <= n; k <<= 1) {
                for (int j = k >> 1; j > 0; j >>= 1) {
                    bitonicSortGPU<<<numBlocks, threadsPerBlock>>>(d_dates, n, k, j);
                    cudaDeviceSynchronize();
                }
            }
            stopTime(&timer);
            std::cout << "Bitonic Sort: <INPUT SIZE: " << n << "> and <THREADS/BLOCK: " << threadsPerBlock << ">" << "\n" << "Elapsed time: " << elapsedTime(timer) << " sec\n";
            break;
        }
            

        case 4:
        {
            startTime(&timer);
            int maxNum = *std::max_element(dates, dates + n);
            for (int exp = 1; maxNum / exp > 0; exp *= 10) {
                radixSortGPU<<<numBlocks, threadsPerBlock>>>(d_dates, out_dates, n, exp);
                cudaDeviceSynchronize();
            }
            stopTime(&timer);
            std::cout << "Radix Sort: <INPUT SIZE: " << n << "> and <THREADS/BLOCK: " << threadsPerBlock << ">" << "\n" << "Elapsed time: " << elapsedTime(timer) << " sec\n";
            break;
        }
    }   

    error_Status = cudaMemcpy(dates, d_dates, n * sizeof(int), cudaMemcpyDeviceToHost);

    if (error_Status!=cudaSuccess)
    {
        std::cout << "cudaMemcpy 2" << "\n";
    }


    // Verification

    // std::cout << "Sorted Dates:\n";
    // for (int i = 0; i < n; i++) {
    //     std::cout << dates[i] << "\n";
    // }

    cudaFree(out_dates);
    cudaFree(d_dates);
    return 0;
}
