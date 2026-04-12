/* Some wrapper functions used instead of unsupported native ones. */

#include <stdio.h>
#include <string.h>
#include <stdarg.h>

#include <termios.h>
#include <unistd.h>


/////////////////////////// Link Time Wrappers ////////////////////////////////

#include <emscripten.h>

EM_ASYNC_JS(void, sync_idbfs_save, (void), {
  Module.FS.syncfs(false, (err) => {
      if (err) console.error('IDBFS save error:', err);
      else console.log('✓ Saved to browser storage');
  });
});
void __cdecl __wrap_getmailstatus() { /* empty */ }
void __cdecl __wrap_nh_uncompress(const char* file_name) { /* empty */ }
void __cdecl __wrap_nh_compress(const char* file_name) { sync_idbfs_save(); }


//////////////////////////////// Other ////////////////////////////////////////

short ospeed = 9600;

static int c_columns = 80;
static int c_lines = 24;

int xterm_js_on_resize(int new_cols, int new_rows) {
    c_columns = new_cols;
    c_lines = new_rows;
    return 0;
}


static char tgoto_buf[1024];
static char tparm_buffer[1024];
static char pc_pad = '\0';

static struct termios old_termios;
int tty_raw_called = 0;

void tty_raw(void) {
    if(tty_raw_called)
        return;

    tty_raw_called = 1;
    struct termios t;

    tcgetattr(STDIN_FILENO, &old_termios);
    t = old_termios;

    t.c_lflag &= ~(ICANON | ECHO);  // disable canonical mode + echo
    t.c_cc[VMIN] = 1;               // read 1 char
    t.c_cc[VTIME] = 0;

    tcsetattr(STDIN_FILENO, TCSANOW, &t);
}

void tty_restore(void) {
    if(tty_raw_called) {
        tcsetattr(STDIN_FILENO, TCSANOW, &old_termios);
        tty_raw_called = 0;
    }
}


/* pretend terminal exists */
int tgetent(char *bp, const char *name) {
    tty_raw();
    //atexit(tty_restore);
    return 1;
}

int has_colors(void) {
    return 1;
}

/* numeric capabilities */
int tgetnum(const char *id) {
    if (!strcmp(id, "co")) return c_columns;
    if (!strcmp(id, "li")) return c_lines;
    if (!strcmp(id, "sg")) return -1;  /* no standout glitch */
    if (!strcmp(id, "Co")) return 8;   /* max colors */
    if (!strcmp(id, "pa")) return 64;  /* max color pairs */
    return -1;
}

/* boolean capabilities */
int tgetflag(const char *id) {
    if (!strcmp(id, "bs")) return 1;  /* backspace works */
    if (!strcmp(id, "os")) return 0;  /* no overstrike */
    return 0;
}

/* string capabilities */
char *tgetstr(const char *id, char **area) {
    if (!strcmp(id, "cl")) return "\033[2J";      /* clear screen */
    if (!strcmp(id, "cm")) return "\033[%i%p2%d;%p1%dH";/* cursor move */
    if (!strcmp(id, "ce")) return "\033[K";       /* clear to end of line */
    if (!strcmp(id, "so")) return "\033[7m";      /* standout on */
    if (!strcmp(id, "se")) return "\033[0m";      /* standout off */
    if (!strcmp(id, "le")) return "\033[D";       /* cursor left (backspace equivalent for movement) */
    if (!strcmp(id, "nd")) return "\033[C";       /* cursor right */
    if (!strcmp(id, "up")) return "\033[A";       /* cursor up */
    if (!strcmp(id, "do")) return "\033[B";       /* cursor down */
    if (!strcmp(id, "ho")) return "\033[H";       /* cursor home */
    if (!strcmp(id, "cd")) return "\033[J";       /* clear to end of screen */
    if (!strcmp(id, "vi")) return "\033[?25l";    /* cursor invisible */
    if (!strcmp(id, "ve")) return "\033[?25h";    /* cursor visible */
    if (!strcmp(id, "dc")) return "\033[P";       /* delete character */
    if (!strcmp(id, "ic")) return "\033[@";       /* insert character */
    if (!strcmp(id, "al")) return "\033[L";       /* insert line */
    if (!strcmp(id, "dl")) return "\033[M";       /* delete line */
    if (!strcmp(id, "ti")) return "\033[?1049h";  /* enter alternate screen buffer */
    if (!strcmp(id, "te")) return "\033[?1049l";  /* exit alternate screen buffer */
    if (!strcmp(id, "bc")) return "\010";         /* backspace */
    if (!strcmp(id, "xd")) return "\033[B";       /* cursor down (alternative) */
    if (!strcmp(id, "us")) return "\033[4m";      /* underline start */
    if (!strcmp(id, "ue")) return "\033[24m";     /* underline end */
    if (!strcmp(id, "mr")) return "\033[7m";      /* reverse on */
    if (!strcmp(id, "as")) return "\033(0";       /* alt charset start */
    if (!strcmp(id, "ae")) return "\033(B";       /* alt charset end */
    if (!strcmp(id, "pc")) return &pc_pad;        /* pad char */
    
    //if (!strcmp(id, "setaf")) return "\033[3%p1%dm"; /* set foreground color */
    //if (!strcmp(id, "setab")) return "\033[4%p1%dm"; /* set background color */
    //if (!strcmp(id, "op")) return "\033[39;49m";     /* original pair (reset colors) */
    //if (!strcmp(id, "me")) return "\033[0m";      /* end modes */
    
    if (!strcmp(id, "setaf"))
        return "\033[%?%p1%{8}%<%t3%p1%d%e9%p1%{8}-%d%;m";

    if (!strcmp(id, "setab"))
        return "\033[%?%p1%{8}%<%t4%p1%d%e10%p1%{8}-%d%;m";

    if (!strcmp(id, "AF")) return "\033[3%p1%dm";
    if (!strcmp(id, "AB")) return "\033[4%p1%dm";

    if (!strcmp(id, "op")) return "\033[0m";     /* original pair (reset colors) */
    if (!strcmp(id, "md")) return "\033[1m";  /* bold */
    if (!strcmp(id, "me")) return "\033[0m";  /* end modes */
    if (!strcmp(id, "mb")) return "\033[5m";  /* blink (optional) */

    return 0;
}

char *tgoto(const char *cm, int col, int row) {
    /* ANSI cursor move */
    snprintf(tgoto_buf, sizeof(tgoto_buf), "\033[%d;%dH", row + 1, col + 1);
    return tgoto_buf;
}

void tputs(const char *str, int affcnt, int (*putc)(int)) { // int
    if(str)
      while (*str) {
        putc(*str++);
      }
    //fflush(stdout);
    //return 0;
}


char *tparm(const char *str, int color)
{
    if (str[2] == '3')  /* foreground */
        snprintf(tparm_buffer, sizeof(tparm_buffer), "\033[3%dm", color);
    else                /* background */
        snprintf(tparm_buffer, sizeof(tparm_buffer), "\033[4%dm", color);

    return tparm_buffer;
}


