/* Tester ft_printf: chaque appel est compare a snprintf (meme sortie et meme retour que printf). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <stdint.h>
#include <signal.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/wait.h>

int	ft_printf(const char *fmt, ...);

static const char	*g_conv;
static int			g_vg;		/* --vg: appels directs sans fork, pour valgrind */
static int			g_total;
static int			g_failed;
static int			g_crashes;
static int			g_out[2];
static int			g_ret[2];
static pid_t		g_pid;
static char			g_long[3001];

static void	put_esc(FILE *f, const char *s, int len)
{
	fputc('"', f);
	for (int i = 0; i < len; i++)
	{
		unsigned char	c = s[i];

		if (c == '\n')
			fputs("\\n", f);
		else if (c == '"' || c == '\\')
			fprintf(f, "\\%c", c);
		else if (c < 32 || c >= 127)
			fprintf(f, "\\x%02x", c);
		else
			fputc(c, f);
	}
	fputc('"', f);
}

static FILE	*open_log(void)
{
	char	path[256];

	snprintf(path, sizeof path, "errors/%s.txt", g_conv);
	return (fopen(path, "a"));
}

/* fork: le fils ecrit dans un pipe, un crash ou une boucle infinie ne tue que lui */
static int	start(void)
{
	if (pipe(g_out) || pipe(g_ret))
		exit(3);
	fflush(stdout);
	g_pid = fork();
	if (g_pid < 0)
		exit(3);
	if (g_pid)
		return (0);
	close(g_out[0]);
	close(g_ret[0]);
	dup2(g_out[1], 1);
	close(g_out[1]);
	alarm(5);
	return (1);
}

static void	stop(int r)
{
	fflush(stdout);
	write(g_ret[1], &r, sizeof r);
	_exit(0);
}

static void	finish(const char *call, const char *exp, int eret)
{
	static char	got[65536];
	int			glen = 0;
	int			gret = 0;
	int			n;
	int			st;
	int			ok;
	FILE		*f;

	close(g_out[1]);
	close(g_ret[1]);
	while (glen < (int)sizeof got && (n = read(g_out[0], got + glen, sizeof got - glen)) > 0)
		glen += n;
	n = read(g_ret[0], &gret, sizeof gret);
	close(g_out[0]);
	close(g_ret[0]);
	waitpid(g_pid, &st, 0);
	g_total++;
	ok = !WIFSIGNALED(st) && n == sizeof gret && gret == eret
		&& glen == eret && !memcmp(got, exp, eret);
	if (ok)
		return ;
	g_failed++;
	if (!(f = open_log()))
		return ;
	if (WIFSIGNALED(st))
	{
		g_crashes++;
		fprintf(f, "[%s] ft_printf(%s)\n", WTERMSIG(st) == SIGALRM ? "TIMEOUT" : "CRASH", call);
		fprintf(f, "  signal %d (%s)\n\n", WTERMSIG(st), strsignal(WTERMSIG(st)));
	}
	else
	{
		fprintf(f, "[KO] ft_printf(%s)\n  attendu: ", call);
		put_esc(f, exp, eret);
		fprintf(f, "  (retour %d)\n  obtenu : ", eret);
		put_esc(f, got, glen);
		fprintf(f, "  (retour %d)\n\n", gret);
	}
	fclose(f);
}

#define T(...) do { \
	char	e_[8192]; \
	int		r_ = snprintf(e_, sizeof e_, __VA_ARGS__); \
	if (g_vg) { ft_printf(__VA_ARGS__); break ; } \
	if (start()) stop(ft_printf(__VA_ARGS__)); \
	finish(#__VA_ARGS__, e_, r_); \
} while (0)

static void	test_c(void)
{
	T("%c", 'a');
	T("%c", '0');
	T("%c", ' ');
	T("%c", '\n');
	T("%c", '\0');
	T("%c", 127);
	T("%c", 255);
	T("%c", -1);
	T("%c%c%c", 'a', 'b', 'c');
	T(" %c %c %c ", '1', '\0', '2');
	T("debut %c fin", 'x');
	T("%c%c", '\0', '\0');
}

static void	test_s(void)
{
	T("%s", "");
	T("%s", "hello");
	T("%s", "rubben ouaf ouaf");
	T("%s", (char *)NULL);
	T(" %s ", (char *)NULL);
	T("%s%s%s", "a", "", "b");
	T("%s %s", "", "");
	T("debut %s fin", "milieu");
	T("%s", "\t\n\v\f\r");
	T("%s", "%d %s %%");
	T("%s", g_long);
	T("%s|%s", g_long, "fin");
}

static void	test_p(void)
{
	int	x;

	T("%p", (void *)0);
	T(" %p ", (void *)0);
	T("%p", (void *)1);
	T("%p", (void *)15);
	T("%p", (void *)16);
	T("%p", &x);
	T("%p", (void *)g_long);
	T("%p", (void *)-1);
	T("%p", (void *)LONG_MIN);
	T("%p", (void *)LONG_MAX);
	T("%p", (void *)ULONG_MAX);
	T("%p %p", (void *)0, (void *)0);
	T("%p%p", (void *)0xdeadbeef, (void *)0x2a);
}

#define INTS(F, F3) \
	T(F, 0); T(F, 1); T(F, -1); T(F, 9); T(F, 10); T(F, -10); T(F, 42); \
	T(F, -42); T(F, 100); T(F, 123456789); T(F, -123456789); T(F, INT_MAX); \
	T(F, INT_MIN); T(F, INT_MAX - 1); T(F, INT_MIN + 1); \
	T(F3, INT_MIN, 0, INT_MAX); T(F3, -1, 1, -100)

static void	test_d(void)
{
	INTS("%d", " %d %d %d ");
}

static void	test_i(void)
{
	INTS("%i", " %i %i %i ");
}

static void	test_u(void)
{
	T("%u", 0);
	T("%u", 1);
	T("%u", 9);
	T("%u", 10);
	T("%u", 42);
	T("%u", 4242);
	T("%u", -1);
	T("%u", -42);
	T("%u", INT_MAX);
	T("%u", INT_MIN);
	T("%u", UINT_MAX);
	T("%u", UINT_MAX - 1);
	T(" %u %u %u ", 0, UINT_MAX, INT_MIN);
}

#define HEXS(F, F3) \
	T(F, 0); T(F, 1); T(F, 9); T(F, 10); T(F, 15); T(F, 16); T(F, 17); \
	T(F, 42); T(F, 255); T(F, 256); T(F, 0xabcdef); T(F, 0xdeadbeef); \
	T(F, -1); T(F, -42); T(F, INT_MAX); T(F, INT_MIN); T(F, UINT_MAX); \
	T(F3, 0, UINT_MAX, INT_MIN)

static void	test_x(void)
{
	HEXS("%x", " %x %x %x ");
}

static void	test_X(void)
{
	HEXS("%X", " %X %X %X ");
}

static void	test_pourcent(void)
{
	T("%%");
	T("%%%%");
	T(" %% ");
	T("100%%");
	T("%%c");
	T("%%d %%s");
	T("%%%d", 42);
	T("%d%%", 42);
	T("%%%c%%", 'a');
}

static void	test_mix(void)
{
	int	x;

	T("");
	T("hello");
	T("rubben\n");
	T("\n\n\n");
	T("\t\v\f\r");
	T("%c%s%p%d%i%u%x%X%%", 'a', "b", (void *)0x2a, -1, 2, 3, 255, 255);
	T("%c|%s|%p|%d|%i|%u|%x|%X|%%", '\0', (char *)NULL, (void *)0, INT_MIN, INT_MAX, UINT_MAX, UINT_MAX, 0);
	T("%s a %d ans et %u os, adresse %p", "rubben", 4, 206u, &x);
	T("%d%d%d%d%d%d%d%d%d%d", 0, 1, 2, 3, 4, 5, 6, 7, 8, 9);
	T("%s%s%s%s%s", "1", "22", "333", "4444", "55555");
	T("%x %X %x %X", 0xabc, 0xabc, -1, -1);
	T("%s", g_long);
	T("fin sans conversion %%");
}

/* ---------- bonus: flags -0. # + espace et largeur (combinaisons definies par printf seulement) ---------- */

static void	test_largeur(void)
{
	int	x;

	T("%5c", 'a');
	T("%1c", 'a');
	T("%3c", '\0');
	T("%5s", "abc");
	T("%1s", "hello");
	T("%10s", "");
	T("%10s", (char *)NULL);
	T("%20p", &x);
	T("%20p", (void *)0);
	T("%5d", 42);
	T("%5d", -42);
	T("%1d", 12345);
	T("%12d", INT_MIN);
	T("%5i", 7);
	T("%11u", UINT_MAX);
	T("%10x", 0xabc);
	T("%10X", 0xabc);
	T("|%4c|%6s|%8d|", 'z', "ab", -1);
}

static void	test_moins(void)
{
	int	x;

	T("%-5c", 'a');
	T("%-1c", 'a');
	T("%-3c", '\0');
	T("%-5s", "abc");
	T("%-2s", "hello");
	T("%-10s", (char *)NULL);
	T("%-20p", &x);
	T("%-20p", (void *)0);
	T("%-5d", 42);
	T("%-5d", -42);
	T("%-12d", INT_MIN);
	T("%-5i", 7);
	T("%-11u", UINT_MAX);
	T("%-10x", 0xabc);
	T("%-10X", 0xabc);
	T("|%-3c|%-3c|", 'a', 'b');
	T("%-05d", 42);
}

static void	test_zero(void)
{
	T("%05d", 42);
	T("%05d", -42);
	T("%05d", 0);
	T("%01d", 0);
	T("%03d", 12345);
	T("%012d", INT_MIN);
	T("%05i", -7);
	T("%011u", UINT_MAX);
	T("%05u", 42);
	T("%08x", 0xabc);
	T("%08X", 0xabc);
	T("%02x", 0);
}

static void	test_precision(void)
{
	T("%.0d", 0);
	T("%.d", 0);
	T("%.0d", 5);
	T("%.5d", 42);
	T("%.5d", -42);
	T("%.12d", INT_MIN);
	T("%.0i", 0);
	T("%.3i", -7);
	T("%.3u", 7);
	T("%.0u", 0);
	T("%.8x", 255);
	T("%.0x", 0);
	T("%.8X", 255);
	T("%.3s", "hello");
	T("%.0s", "hello");
	T("%.s", "abc");
	T("%.10s", "hi");
	T("%8.3d", 42);
	T("%-8.3d", -42);
	T("%08.3d", 42);
	T("%5.0d", 0);
	T("%10.5s", "hello world");
	T("%-10.2s", "hello");
	T("%10.4x", 0xab);
}

static void	test_diese(void)
{
	T("%#x", 0);
	T("%#X", 0);
	T("%#x", 42);
	T("%#X", 42);
	T("%#x", UINT_MAX);
	T("%#10x", 42);
	T("%#-10x", 42);
	T("%#010x", 42);
	T("%#.5x", 42);
	T("%#X%#x", 1, 1);
}

static void	test_plus(void)
{
	T("%+d", 0);
	T("%+d", 42);
	T("%+d", -42);
	T("%+d", INT_MAX);
	T("%+d", INT_MIN);
	T("%+i", 7);
	T("%+5d", 42);
	T("%+-5d", 42);
	T("%+05d", 42);
	T("%+.3d", 42);
	T("%+ d", 42);
	T("% +d", 42);
}

static void	test_espace(void)
{
	T("% d", 0);
	T("% d", 42);
	T("% d", -42);
	T("% d", INT_MIN);
	T("% i", 7);
	T("% 5d", 42);
	T("% -5d", 42);
	T("% 05d", 42);
	T("% .3d", 42);
	T("%  d", 42);
}

#define CONVS X(c) X(s) X(p) X(d) X(i) X(u) X(x) X(X) X(pourcent) X(mix) \
	X(largeur) X(moins) X(zero) X(precision) X(diese) X(plus) X(espace)

int	main(int ac, char **av)
{
	char	*name = ac >= 2 ? av[ac - 1] : "";

	memset(g_long, 'r', sizeof g_long - 1);
	if (ac == 2 && !strcmp(av[1], "--list"))
	{
#define X(n) puts(#n);
		CONVS
#undef X
		return (0);
	}
	g_vg = ac == 3 && !strcmp(av[1], "--vg");
	if (g_vg)
		dup2(open("/dev/null", O_WRONLY), 1);
	g_conv = name;
#define X(n) if (!strcmp(name, #n)) { test_##n(); printf("%d %d %d\n", g_total, g_failed, g_crashes); return (g_failed != 0); }
	CONVS
#undef X
	fprintf(stderr, "usage: %s [--list | [--vg] conversion]\n", av[0]);
	return (2);
}
