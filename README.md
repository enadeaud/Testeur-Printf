# Testeur-Printf 🐕 rubben

Tester pour le ft_printf de 42 (sujet v12.1, partie obligatoire `cspdiuxX%` et bonus).

```bash
./test.sh                  # 1er lancement: ajoute les alias `rubben` et `Rubben` a ~/.zshrc et ~/.bashrc
Rubben                     # depuis le dossier de ton ft_printf: tout tester
rubben c                   # seulement %c (accepte aussi %c)
rubben s p %               # plusieurs conversions; `%`, `%%` ou `pourcent` pour %%
rubben mix                 # plusieurs conversions dans un meme appel
rubben ~/ft_printf d       # avec un chemin
Rubben bonus               # tout + make bonus + tests des flags (le bonus n'est jamais lance sans ce mot)
rubben precision diese     # un groupe bonus cible (active make bonus)
```

Sans chemin: dossier courant s'il contient `ft_printf.h`, sinon le dossier parent du tester.

- Makefile: `libftprintf.a` a la racine, regles, flags, pas de relink, `ar` (pas `libtool`).
- `ft_printf.h` avec le bon prototype, fonctions externes autorisees uniquement (`nm`).
- Norminette (le dossier du tester est exclu s'il est clone dans le projet).
- README.md (chapitre V): 1re ligne en italique, Description / Instructions / Resources, IA, algorithme et structure de donnees.
- Chaque appel est compare a `printf` (sortie octet par octet et valeur de retour), y compris `%c` avec `'\0'`, `%s` NULL, `%p` NULL, INT_MIN, UINT_MAX...
- Chaque cas tourne dans un processus a part: un crash ou une boucle infinie est note et les suivants continuent.
- Chaque conversion passe aussi sous valgrind (fuites et acces invalides).
- Avec une conversion ciblee, les verifs Makefile / norminette / README sont sautees pour aller vite.
- Bonus (`bonus`, `--bonus` ou `-b`): regle `bonus`, pas de relink sur `make bonus`, fichiers `*_bonus.c`,
  puis les groupes `largeur` (%5d), `moins` (-), `zero` (0), `precision` (.), `diese` (#), `plus` (+), `espace` ( ).
  Seules les combinaisons definies par printf sont testees (pas de `%05s` ni de `%#d`).
- Les erreurs sont ecrites dans `errors/<conversion>.txt` (appel, attendu, obtenu).
