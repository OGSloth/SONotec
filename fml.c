#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>


uint64_t notec(uint32_t n, char const *calc) {
    int i = 0;
    while(calc[i] != '\0') {
        printf("%c", calc[i]);
        i++;
    }
    return n*n;
}

int main () {
    uint32_t n = 3;
    char *xd = (char*) malloc((128)*sizeof(char));
    scanf("%s", xd);
    uint64_t sol = notec(n, xd);
    printf("Sol = %lu\n", sol);
	return 0;
}
