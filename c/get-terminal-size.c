#include <stdio.h>
#include <sys/ioctl.h>
#include <unistd.h>

int main() {
  struct winsize ws;

  if (ioctl(STDIN_FILENO, TIOCGWINSZ, &ws) == -1) {
    perror("ioctl");
    return 1;
  }

  printf("Rows: %d, Cols: %d\n", ws.ws_row, ws.ws_col);
  return 0;
}
