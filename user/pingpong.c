#include <kernel/types.h>
#include <user/user.h>

int main(int argc, char *argv[])
{
    int p[2]; // enum PIPE_END { REC = 0, SND = 1 };
    pipe(p);

    if (fork() != 0) // parent
    {
        char buf[20];
        fprintf(p[1], "parent\n");
        wait(0);
        if (read(p[0],buf,sizeof(buf)) > 0)
        {
            printf("%d: received pong\n", getpid(), buf);
        }
        exit(0);
        
    }
    else // child
    {
        char buf[20];
        if (read(p[0],buf,sizeof(buf)) > 0)
        {
            printf("%d: received ping\n", getpid(), buf);
        }
        fprintf(p[1], "child\n");
        exit(0);
    }
    exit(0);
}