#!/bin/bash
# usage: rubben [chemin_vers_ft_printf] [bonus] [conversion ...]   (c s p d i u x X % mix)
#   bonus: make bonus + groupes largeur moins zero precision diese plus espace
#   --strict (ou -s): stdout ferme avant le debut et au milieu de chaque test, retour -1 attendu
#   sans chemin: le dossier courant s'il contient ft_printf.h, sinon le dossier parent du tester
SELF=$(realpath "$0")
DIR=$(dirname "$SELF")

if [ -n "$1" ] && [ -d "$1" ]; then PF=$(realpath "$1"); shift
elif [ -f "$PWD/ft_printf.h" ]; then PF=$PWD
else PF=$(realpath "$DIR/..")
fi
cd "$DIR" || exit 1
ERR=$DIR/errors

G=$'\e[32m'; R=$'\e[31m'; Y=$'\e[33m'; C=$'\e[36m'; M=$'\e[35m'; D=$'\e[2m'; B=$'\e[1m'; N=$'\e[0m'
OKS="${G}✔${N}"; KOS="${R}✘${N}"

# alias "rubben" et "Rubben" ajoutes une seule fois dans les rc du shell
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
	[ -f "$rc" ] || continue
	for a in rubben Rubben; do
		if ! grep -q "alias $a=" "$rc"; then
			echo "alias $a='$SELF'" >> "$rc"
			ALIAS_ADDED=1
		fi
	done
done

echo "${Y}${B}"
cat <<'EOF'
       / \__
      (    @\___      ____  _   _ ____  ____  _____ _   _
      /         O    |  _ \| | | | __ )| __ )| ____| \ | |
     /   (_____/     | |_) | | | |  _ \|  _ \|  _| |  \| |
    /_____/   U      |  _ <| |_| | |_) | |_) | |___| |\  |
                     |_| \_\\___/|____/|____/|_____|_| \_|  ft_printf tester
EOF
echo "${N}"
echo "  ${D}ft_printf :${N} $PF"
[ -n "$ALIAS_ADDED" ] && echo "  ${Y}alias 'rubben' et 'Rubben' ajoutes — ouvre un nouveau terminal ou fais: source ~/.zshrc${N}"
echo

section() { printf "\n  ${B}${C}%s${N}\n  ${D}%s${N}\n" "$1" "────────────────────────────────────────────────────────────"; }
check() { [ "$2" = 1 ] && printf "    %s %s\n" "$OKS" "$1" || printf "    %s %s\n" "$KOS" "$1"; }

[ -f "$PF/Makefile" ] || { echo "  $KOS Makefile introuvable dans $PF"; exit 1; }

# conversions ciblees: accepte "c", "%c", "%", "%%", "pourcent", "mix"
# "bonus" (ou --bonus) lance les tests des flags; un groupe bonus cible les active aussi
ALL=" c s p d i u x X pourcent mix "
BALL=" largeur moins zero precision diese plus espace "
CONVS=""; BONUS=""; TARGETED=0
for a in "$@"; do
	case $a in %|%%|pourcent) a=pourcent ;; %*) a=${a#%} ;; bonus|--bonus|-b) BONUS=1; continue ;;
		--strict|-s|strict) export TESTER_STRICT=1; continue ;; esac
	TARGETED=$((TARGETED + 1))
	if [[ "$ALL" == *" $a "* ]]; then CONVS="$CONVS $a"
	elif [[ "$BALL" == *" $a "* ]]; then CONVS="$CONVS $a"; BONUS=1
	else echo "  $KOS conversion inconnue: $a ${D}(disponibles:$ALL| bonus:$BALL)${N}"; fi
done
[ $TARGETED != 0 ] && [ -z "$CONVS" ] && exit 1
[ $TARGETED = 0 ] && CONVS=$ALL && [ -n "$BONUS" ] && CONVS="$ALL$BALL"
[ -n "$TESTER_STRICT" ] && echo "  ${R}${B}MODE STRICT${N} ${D}— stdout ferme avant le debut et au milieu de chaque test (retour -1 attendu)${N}"
[ -n "$BONUS" ] && echo "  ${M}${B}MODE BONUS${N} ${D}— make bonus, flags '-0.# +' et largeur${N}"

[ $TARGETED = 0 ] && section "Makefile & regles"
if [ -n "$BONUS" ] && ! grep -qE "^bonus\s*:" "$PF/Makefile"; then
	echo "    $KOS regle bonus absente du Makefile"; exit 1
fi
make -C "$PF" fclean >/dev/null 2>&1
if ! make -C "$PF" >/dev/null 2>"$DIR/.make.log"; then
	echo "    $KOS make a echoue:"; sed 's/^/      /' "$DIR/.make.log"; exit 1
fi
[ -f "$PF/libftprintf.a" ] || { echo "    $KOS libftprintf.a absent a la racine apres make"; exit 1; }
# conversions ciblees: on saute les verifs Makefile / norminette / README pour aller vite
if [ $TARGETED = 0 ]; then
	check "libftprintf.a cree a la racine" 1
	before=$(stat -c %Y "$PF/libftprintf.a"); sleep 1
	make -C "$PF" >/dev/null 2>&1
	check "pas de relink" "$([ "$before" = "$(stat -c %Y "$PF/libftprintf.a")" ] && echo 1)"
fi
# make bonus apres le relink de make: c'est l'archive bonus qui est testee ensuite
if [ -n "$BONUS" ]; then
	if ! make -C "$PF" bonus >/dev/null 2>"$DIR/.make.log"; then
		echo "    $KOS make bonus a echoue:"; sed 's/^/      /' "$DIR/.make.log"; exit 1
	fi
fi
if [ $TARGETED = 0 ]; then
	if [ -n "$BONUS" ]; then
		before=$(stat -c %Y "$PF/libftprintf.a"); sleep 1
		make -C "$PF" bonus >/dev/null 2>&1
		check "pas de relink (make bonus)" "$([ "$before" = "$(stat -c %Y "$PF/libftprintf.a")" ] && echo 1)"
		check "regle bonus" 1
		check "bonus dans des fichiers *_bonus.c" "$(find "$PF" -path "$DIR" -prune -o -name '*_bonus.c' -print | grep -q . && echo 1)"
	fi
	for rule in '\$\(NAME\)' all clean fclean re; do
		check "regle ${rule//\\/}" "$(grep -qE "^${rule}\s*:" "$PF/Makefile" && echo 1)"
	done
	check "flags -Wall -Wextra -Werror" "$(grep -q -- -Wall "$PF/Makefile" && grep -q -- -Wextra "$PF/Makefile" && grep -q -- -Werror "$PF/Makefile" && echo 1)"
	check "archive creee avec ar (libtool interdit)" "$(grep -qw ar "$PF/Makefile" && ! grep -qw libtool "$PF/Makefile" && echo 1)"
	check "ft_printf.h avec le prototype int ft_printf(const char *, ...)" \
		"$(grep -qE 'int[[:space:]]+ft_printf[[:space:]]*\([[:space:]]*const[[:space:]]+char[[:space:]]*\*[^,]*,[[:space:]]*\.\.\.[[:space:]]*\)' "$PF/ft_printf.h" 2>/dev/null && echo 1)"
	# symboles appeles mais non definis dans l'archive = fonctions externes
	bad=$(nm "$PF/libftprintf.a" 2>/dev/null | awk '$1 == "U" { u[$2] = 1 } NF == 3 { d[$3] = 1 }
		END { for (s in u) if (!(s in d)) print s }' | grep -vxE 'malloc|free|write|__stack_chk_fail|_GLOBAL_OFFSET_TABLE_' | tr '\n' ' ')
	check "fonctions externes autorisees (malloc, free, write, va_*)" "$([ -z "$bad" ] && echo 1)"
	[ -n "$bad" ] && printf "      ${D}↳ interdit: %s${N}\n" "$bad"

	section "Norminette"
	if command -v norminette >/dev/null; then
		# le tester peut etre clone dans le projet: on l'exclut
		norm=$(find "$PF" -path "$DIR" -prune -o \( -name '*.c' -o -name '*.h' \) -print0 | xargs -0 -r norminette 2>&1 | grep -E 'Error' )
		check "norminette" "$([ -z "$norm" ] && echo 1)"
		[ -n "$norm" ] && echo "$norm" | head -8 | sed "s/^/      ${D}↳ /;s/$/${N}/"
	else
		echo "    ${Y}! norminette absente: pip install norminette${N}"
	fi

	section "README.md"
	RM="$PF/README.md"
	if [ -f "$RM" ]; then
		check "README.md a la racine" 1
		first=$(head -n1 "$RM" | tr -d '\r')
		check "1re ligne en italique: *This project has been created as part of the 42 curriculum by <login>*" \
			"$(echo "$first" | grep -qE '^([*_])This project has been created as part of the 42 curriculum by [^*_]+\1[[:space:]]*$' && echo 1)"
		for s in Description Instructions Resources; do
			check "section \"$s\"" "$(grep -qiE "^#+[[:space:]]*$s" "$RM" && echo 1)"
		done
		check "usage de l'IA decrit (mot AI/IA dans le README)" "$(grep -qwiE 'AI|IA|ChatGPT|Claude|LLM' "$RM" && echo 1)"
		check "explication de l'algorithme et de la structure de donnees" \
			"$(grep -qiE 'algorithm|algorithme' "$RM" && grep -qiE 'data structure|structure de donn' "$RM" && echo 1)"
	else
		check "README.md a la racine" 0
	fi
fi

cc -g -w -fno-builtin tester.c "$PF/libftprintf.a" -Wl,--wrap=write -o tester 2>"$DIR/.make.log" \
	|| { echo "    $KOS compilation du tester echouee:"; sed 's/^/      /' "$DIR/.make.log"; exit 1; }

VG=$(command -v valgrind)
[ -z "$VG" ] && echo "    ${Y}! valgrind absent: pas de verification memoire${N}"
[ $TARGETED = 0 ] && rm -rf "$ERR"
mkdir -p "$ERR"
section "Conversions"
ok=0; nb=0
for c in $CONVS; do
	[ $c = largeur ] && section "Bonus — flags et largeur"
	rm -f "$ERR/$c.txt"
	nb=$((nb + 1))
	out=$(timeout 120 ./tester "$c" 2>/dev/null); rc=$?
	read -r total failed crashes <<< "$out"
	vg=""
	case $rc in
		0|1)
			[ "$failed" = 0 ] && res="$OKS ${G}$(printf '%3s/%-3s' "$total" "$total")${N}" \
				|| res="$KOS ${R}$(printf '%3s/%-3s' "$((total - failed))" "$total")${N}"
			[ "$crashes" != 0 ] && res="$res ${R}💥 $crashes crash/timeout${N}" ;;
		124) res="$KOS ${R}timeout global${N}"; echo "[TIMEOUT] le tester a ete tue apres 120s" >> "$ERR/$c.txt" ;;
		*) res="$KOS ${R}crash du tester (code $rc)${N}"; echo "[CRASH] code de sortie $rc" >> "$ERR/$c.txt" ;;
	esac
	# apres un crash valgrind planterait aussi: on ne le lance que si tout a tourne
	if [ -n "$VG" ] && { [ $rc = 0 ] || [ $rc = 1 ]; } && [ "$crashes" = 0 ]; then
		timeout 300 valgrind -q --leak-check=full --show-leak-kinds=definite,indirect \
			--errors-for-leak-kinds=definite,indirect --error-exitcode=42 --log-file="$DIR/.vg.log" \
			./tester --vg "$c" >/dev/null 2>&1
		if [ $? = 42 ]; then
			vg="${R}🦴 valgrind KO${N}"
			{ echo "[VALGRIND] fuite ou acces memoire invalide:"; echo; cat "$DIR/.vg.log"; echo; } >> "$ERR/$c.txt"
		else
			vg="${G}🦴 mem ok${N}"
		fi
	fi
	[ -f "$ERR/$c.txt" ] || ok=$((ok + 1))
	case $c in
		pourcent) label="%%" ;; mix) label="mix" ;; largeur) label="largeur (%5d)" ;;
		moins) label="'-'" ;; zero) label="'0'" ;; precision) label="'.'" ;; diese) label="'#'" ;;
		plus) label="'+'" ;; espace) label="' '" ;; *) label="%$c" ;;
	esac
	printf "    ${B}%-14s${N} %s  %s\n" "$label" "$res" "$vg"
	if [ -f "$ERR/$c.txt" ]; then
		first=$(grep -m1 -A1 -E '^\[(KO|CRASH|TIMEOUT|STDOUT FERME|VALGRIND)' "$ERR/$c.txt" | tr -s ' ' | tr '\n' ' ' | cut -c1-90)
		printf "      ${D}↳ %s${N}\n" "$first"
	fi
done
rm -f "$DIR/.vg.log" "$DIR/.make.log" tester
make -C "$PF" fclean >/dev/null 2>&1

section "Resultat"
width=40
fill=$((nb ? ok * width / nb : 0))
bar="${G}$(printf '█%.0s' $(seq 1 $fill))${R}$(printf '░%.0s' $(seq 1 $((width - fill))))${N}"
[ $fill = 0 ] && bar="${R}$(printf '░%.0s' $(seq 1 $width))${N}"
[ $fill = $width ] && bar="${G}$(printf '█%.0s' $(seq 1 $width))${N}"
printf "    %s  ${B}%d/%d${N} conversions OK\n" "$bar" "$ok" "$nb"
if [ $ok = $nb ]; then
	echo "    ${G}${B}Ouaf ouaf ! Rubben remue la queue, tout est bon 🐕${N}"
else
	echo "    ${M}Rubben grogne... grrr 🐕${N}  ${R}Details des erreurs:${N} $ERR/<conversion>.txt"
fi
echo
[ $ok = $nb ]
