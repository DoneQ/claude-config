# TypeScript — Globalne reguły

Te reguły obowiązują WSZĘDZIE gdzie piszę TypeScript. Reguły projektowe (CLAUDE.md w katalogu projektu) mogą je zaostrzyć, ale **nie mogą złagodzić**.

## Formatting (Prettier-aligned)

- `printWidth: 90`
- **No semicolons** — nigdy `;` na końcu instrukcji
- `singleQuote: true` — zawsze `'foo'`, nigdy `"foo"` (poza JSON)
- `tabWidth: 2`, `useTabs: false`
- `trailingComma: 'es5'`
- `arrowParens: 'always'` — `(x) => ...`, nigdy `x => ...`
- `bracketSpacing: true` — `{ foo }`, nie `{foo}`

## Strict mode — ZAWSZE

- `strict: true` w tsconfig (włącznie z `strictNullChecks`, `noImplicitAny`)
- `noImplicitReturns: true`
- `noFallthroughCasesInSwitch: true`
- `strictTemplates: true` (Angular)

## Typowanie

- **Explicit return type** dla każdej funkcji/metody (eslint `explicit-function-return-type`).
  - TAK: `getUser(): User { ... }`, `private fetch$(): Observable<Data> { ... }`
  - NIE: `getUser() { ... }`
- `readonly` na polach klasy które nie powinny być reassignowane
- Preferuj `interface` nad `type` dla obiektów; `type` dla unionów/tuple/utility
- Nigdy `any` bez `// eslint-disable` z uzasadnieniem; jeśli typu nie znasz → `unknown` + narrow

## Naming

- **Klasy / interfejsy / enumy**: PascalCase
- **Wartości enuma**: UPPER_CASE
- **Pliki**: `kebab-case` z sufiksem typu (`user-profile.component.ts`, `auth.service.ts`, `cart-item.model.ts`)
- **Observables**: sufiks `$` (`data$`, `loading$`, `#destroy$`)
- **Boolean**: prefiksy `is`/`has`/`should`/`can` (`isLoading`, `hasError`, `canEdit`)
- **Metody / funkcje — nazwa opisuje CO ROBI, nie CO JĄ WYWOŁUJE**. Trigger/kontekst użycia wynika z miejsca wywołania (`(click)=`, `(focus)=`, `@HostListener`) — nazwa metody MA dokładać informację, nie ją powtarzać.
  - ❌ `onClick`, `onFocus`, `onInputFocus`, `onProductSelected`, `onWindowResize`, `onRemoveClick` — nazwa = trigger, zero nowej informacji ponad `(event)=`.
  - ✅ `navigateToProduct`, `openSuggestionsPanel`, `closePanel`, `removeRecentPhrase`, `preventDefaultAndEmitSelected`, `hideMobileMenuOnDesktop` — nazwa = akcja.
  - ❌ **Wariant „nazwa = KIEDY / w jakim KONTEKŚCIE wołana"** (równie zły, hook tego NIE łapie — pilnuj sam): `closeAfterNavigation` (co dokładnie jest „after navigation" w ciele? nic — to mówi GDZIE jest wołana, nie CO robi), `focusOnSidebarOpen`, `doXBeforeSubmit`, `handleYAfterLoad`. Człony `after`/`before`/`on<Coś>`/`when<Coś>` opisują moment wywołania, nie akcję.
  - ✅ Nazwij po akcji: `closeAfterNavigation` → `closePanelAndMobileMenu`, `focusOnSidebarOpen` → `observeAutoFocusInput`. Gdy metoda robi 2 rzeczy — nazwa je WYMIENIA (`closePanelAndMobileMenu`), nie ucieka w kontekst wywołania.
  - **Test**: czytając SAMĄ nazwę (bez patrzenia na binding ani miejsce wywołania) — wiem co metoda robi? Jeśli muszę zobaczyć `(click)=` lub gdzie jest wołana, żeby zrozumieć → nazwa jest zła.
  - **Wyjątek**: Angular lifecycle (`ngOnInit`, `ngOnChanges`, `ngOnDestroy`, `ngAfterViewInit`…) — framework-owe, zostają. Zaczynają się od `ng`, nie `on`.
  - **Why**: `(click)="onClick()"` to tautologia („on click → on click"). Nazwa po akcji przeżywa zmianę triggera (ten sam `navigateToProduct` zadziała z click, enter, czy `@Output`), a `on<Event>` kłamie gdy podepniesz pod inny event.

## Imports

- `simple-import-sort/imports` musi przejść — sortowane grupami
- `unused-imports/no-unused-imports` — żadnych martwych importów
- **NIGDY relative imports z `..`** — używaj path aliases (`@components/*`, `@mops/*`, etc.). Wyjątek: import z tego samego folderu (`./foo`).

## Anty-wzorce (NEVER)

- `null` — używaj `undefined`. Jeśli API zwraca null, mapuj go natychmiast.
- `console.log` w kodzie produkcyjnym — tylko `// TODO: remove` z jasną intencją lub dedykowany Logger
- `as any`, `as unknown as X` — to maskowanie problemu typowego, fix the type
- Leading-semicolon prefix dla cast/spy access (`;(spy as jasmine.Spy).and...`) — capture spy w zmienną
- Mutacja parametrów funkcji — clone i return new

## Komentarze

- **Default: nie pisz**. Dobry kod tłumaczy się sam.
- Komentuj TYLKO gdy "dlaczego" jest nieoczywiste (workaround, ukryty constraint, subtelny invariant)
- NIGDY nie komentuj "co" — czytelnik zobaczy w kodzie
- NIGDY nie referuj task / PR / commit / autora — to rotuje i myli
