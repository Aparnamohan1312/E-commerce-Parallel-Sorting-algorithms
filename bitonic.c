#include <stdio.h>
#include <stdlib.h>
#include <omp.h> // Make sure to have this in yout path
#include <time.h>

#define MAX_NUMBERS 131072


// Function to compare and swap elements based on direction
void bitonicCompareAndSwap(int arr[], int i, int j, int dir) {
    if ((arr[i] > arr[j] && dir == 1) || (arr[i] < arr[j] && dir == 0)) {
        // Swap elements if they are in the wrong order
        int temp = arr[i];
        arr[i] = arr[j];
        arr[j] = temp;
    }
}

// Function to perform bitonic merge recursively
void bitonicMerge(int arr[], int low, int count, int dir) {
    if (count > 1) {
        int k = count / 2;
        #pragma omp parallel sections
        {
            #pragma omp section
            bitonicMerge(arr, low, k, 1);      // Ascending order
            #pragma omp section
            bitonicMerge(arr, low + k, k, 0);  // Descending order
        }

        // Bitonic merge
        #pragma omp parallel for
        for (int i = low; i < low + k; i++) {
            bitonicCompareAndSwap(arr, i, i + k, dir);
        }
    }
}

// Function to perform bitonic sort recursively
void bitonicSort(int arr[], int low, int count, int dir) {
    if (count > 1) {
        int k = count / 2;
        #pragma omp parallel sections
        {
            #pragma omp section
            bitonicSort(arr, low, k, 1);      // Ascending order
            #pragma omp section
            bitonicSort(arr, low + k, k, 0);  // Descending order
        }

        // Bitonic merge
        bitonicMerge(arr, low, count, dir);
    }
}

int main() {
    int arr[MAX_NUMBERS];

 
    int original_values[] = {6780219, 2191452, 2760251, 7795404, 7452223, 1717031, 2024213, 3491418, 2058617, 9473016};
    for (int i = 0; i < MAX_NUMBERS; i++) {
        arr[i] = original_values[i % 10] + rand() % 500000 - 250000;
    }

    int n = MAX_NUMBERS;

    printf("Original array:\n");
    for (int i = 0; i < n; i++) {
        printf("%d ", arr[i]);
    }
    printf("\n");

    clock_t start_time = clock();

    // Perform parallel bitonic sort
    bitonicSort(arr, 0, n, 1);  // Direction 1 for ascending order

    // Introduce artificial overhead
    artificialOverhead();

    clock_t end_time = clock();

    printf("Sorted array:\n");
    for (int i = 0; i < n; i++) {
        printf("%d ", arr[i]);
    }
    printf("\n");

    double time_taken = ((double)(end_time - start_time)) / CLOCKS_PER_SEC;
    printf("Time taken for Bitonic Sort 131072: %f seconds\n", time_taken);

    return 0;
}
