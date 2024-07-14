#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

// This is the code for the user program that finds prime numbers.

void print_primes(int *input, int count)
{
    if (count == 0) 
    {
        exit(0);
    }
    int p[2],prime = *input;

    pipe(p);
    printf("prime %d\n", prime);
    if (fork() == 0){ // child process
        close(p[0]);
        for (int i = 0; i < count; i++)
        {
            write(p[1], (char*) (input + i),4);
        }
        close(p[1]);
        exit(0);
    }else{
        close(p[1]);
        count=0;
        char buffer[4];
        while (read(p[0], buffer, 4) != 0)
        {
            int temp = *(int*) buffer;
            if (temp % prime)
            {
                count++;
                *input++ = temp;
            }
        }
        print_primes(input - count,count);
        close(p[0]);
        wait(0);
    }
    
}

int main(int argc, char *argv[])
{
    int input[34], i = 0;
    for (; i < 34; i++)
    {
        input[i] = i + 2;
    }
    print_primes(input, 34);
    exit(0);
}