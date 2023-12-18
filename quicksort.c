#include <stdio.h>
#include <stdlib.h>
#include <omp.h> // Make sure to have this in yout path
#include <time.h>

#define MAX_NUMBERS 10 // adjust this based on the number of elements in your array

void swap(int* a, int* b) {
    int t = *a;
    *a = *b;
    *b = t;
}

int partition(int arr[], int low, int high) {
    int pivot = arr[high];
    int i = (low - 1);

    for (int j = low; j <= high - 1; j++) {
        if (arr[j] < pivot) {
            i++;
            swap(&arr[i], &arr[j]);
        }
    }

    swap(&arr[i + 1], &arr[high]);
    return (i + 1);
}

void quicksort(int arr[], int low, int high) {
    if (low < high) {
        int pi;

        #pragma omp parallel sections
        {
            #pragma omp section
            {
                pi = partition(arr, low, high);
            }
            #pragma omp section
            {
                quicksort(arr, low, pi - 1);
            }
            #pragma omp section
            {
                quicksort(arr, pi + 1, high);
            }
        }
    }
}

int main() {
    int arr[MAX_NUMBERS] = {6780219, 2191452, 2760251, 7795404, 7452223, 1717031, 2024213, 3491418, 2058617, 9473016};
    int n = MAX_NUMBERS;

    printf("Original array:\n");
    for (int i = 0; i < n; i++) {
        printf("%d ", arr[i]);
    }
    printf("\n");

    clock_t start_time = clock();
    quicksort(arr, 0, n - 1);
    clock_t end_time = clock();

    printf("Sorted array:\n");
    for (int i = 0; i < n; i++) {
        printf("%d ", arr[i]);
    }
    printf("\n");

    double time_taken = ((double)(end_time - start_time)) / CLOCKS_PER_SEC;
    printf("Time taken for parallel quicksort: %f seconds\n", time_taken);

    return 0;
}
