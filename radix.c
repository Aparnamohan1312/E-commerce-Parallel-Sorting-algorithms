#include <stdio.h>
#include <stdlib.h>
#include <omp.h> // Make sure to have this in yout path
#include <time.h>

#define MAX_NUMBERS 131072


int getMax(int arr[], int n) {
    int max = arr[0];
    for (int i = 1; i < n; i++) {
        if (arr[i] > max) {
            max = arr[i];
        }
    }
    return max;
}

// Using counting sort to sort elements based on significant places
void countingSort(int arr[], int n, int exp) {
    const int RANGE = 10;  // Radix is 10

    int output[n];
    int count[RANGE] = {0};

    // Store count of occurrences in count[]
    #pragma omp parallel for
    for (int i = 0; i < n; i++) {
        #pragma omp atomic
        count[(arr[i] / exp) % RANGE]++;
    }

    // Change count[i] so that count[i] contains the actual
    // position of this digit in output[]
    for (int i = 1; i < RANGE; i++) {
        count[i] += count[i - 1];
    }

    // Build the output array
    #pragma omp parallel for
    for (int i = n - 1; i >= 0; i--) {
        #pragma omp critical
        output[count[(arr[i] / exp) % RANGE] - 1] = arr[i];
        #pragma omp atomic
        count[(arr[i] / exp) % RANGE]--;
    }

   

    // Copy the output array to arr[], so that arr[] now contains sorted numbers according to the current digit
    #pragma omp parallel for
    for (int i = 0; i < n; i++) {
        arr[i] = output[i];
    }
}

// Radix Sort
void radixSort(int arr[], int n) {
    int max = getMax(arr, n);

    // Perform counting sort for every digit
    for (int exp = 1; max / exp > 0; exp *= 10) {
        #pragma omp parallel sections
        {
            #pragma omp section
            countingSort(arr, n, exp);
        }
    }
}

int main() {
    int arr[MAX_NUMBERS];

    int original_values[] = {6780219, 2191452, 2760251, 7795404, 7452223, 1717031, 2024213, 3491418, 2058617, 9473016};
    for (int i = 0; i < MAX_NUMBERS; i++) {
        arr[i] = original_values[i % 10] + rand() % 500000 - 250000;
    }

    int n = MAX_NUMBERS;

    printf("Original array Order IDs:\n");
    for (int i = 0; i < n; i++) {
        printf("%d ", arr[i]);
    }
    printf("\n");

    clock_t start_time = clock();

    // Perform parallel radix sort
    radixSort(arr, n);

    clock_t end_time = clock();

    printf("Sorted array Order IDs:\n");
    for (int i = 0; i < n; i++) {
        printf("%d ", arr[i]);
    }
    printf("\n");

    double time_taken = ((double)(end_time - start_time)) / CLOCKS_PER_SEC;
    printf("Time taken for Radix Sort OpenMP 131072: %f seconds\n", time_taken);

    return 0;
}
