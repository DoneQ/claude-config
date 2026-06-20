# Angular — Globalne reguły architektoniczne

Te reguły obowiązują we WSZYSTKICH projektach Angular. Konkretna wersja Angulara (16, 18, …) i jej feature set jest doprecyzowana w `CLAUDE.md` projektu.

## i18n

- **ZAWSZE `$localize`** dla stringów w TS, **`i18n` attribute** dla tekstu w HTML
- NIGDY nie używaj `@ngx-translate` ani innych bibliotek i18n
- Atrybuty: `i18n-title="..."`, `i18n-aria-label="..."`
- **`i18n` / `i18n-*` ZAWSZE jako PIERWSZY atrybut w tagu** — przed `class`, `[binding]`, `(event)`, `data-testid`
  - TAK: `<button i18n class="primary" (click)="x()" data-testid="submit">Save</button>`
  - TAK: `<input i18n-placeholder pInputText placeholder="..." [(ngModel)]="x" data-testid="input" />`
  - NIE: `<button class="primary" i18n (click)="x()">Save</button>` — i18n nie jest pierwszy

## PrimeNG

- Stylowanie p-button przez **host class** (`button-inverted`, `button-no-border`, `button-grey`, `button-transparent`, etc.)
- **NIGDY** przez `[outlined]`, `[text]`, `[severity]` props — projekt ma własny system klas
- Konkretne nazwy klas: w CLAUDE.md projektu (różnią się między projektami)
- Default `<p-button>` (bez klasy) renderuje brand-gradient — to PRIMARY CTA

## Nadpisywanie zewnętrznych komponentów (PrimeNG / Material) — patterny

**Twardy zakaz**: `::ng-deep`, `/deep/`, `>>>` w plikach komponentów — **anty-pattern**. Nowy kod NIE używa ng-deep. Istniejący migruje się świadomą decyzją osobnego refactor zadania, nie milcząco.

1. **Deprecated w Angular** — "no longer supported"
2. **Łamie enkapsulację** — styl przecieka, trudniej debugować
3. **Wymusza specificity wars** — ng-deep + !important vs PrimeNG default → kruche style
4. **Powiela override** — ten sam styl w 5 plikach komponentów

### Właściwe patterny (od najprostszego)

#### 1. Istniejąca klasa modyfikator (FIRST CHOICE)

Sprawdź czy istnieje już globalna klasa modyfikator w `partials/overrides/`:
- monopolex: `_button.overrides.scss` → `.button-grey`, `.button-transparent`, `.button-inverted`, `.button-no-border`, `.search-button`, `.button-success`, `.button-white`
- mops: `_button.override.scss` → `.primary-outline`, `.primary-no-borders`, `.auto-size`, `.medium`, `.configure`

Użycie: `<p-button class="button-grey">`.

#### 2. Nowa klasa modyfikator (gdy wariant powtarzalny)

Wariant używany w >1 miejscu → **dodaj klasę do globalnego override**, NIE do komponentu:

```scss
// partials/overrides/primeng/_button.overrides.scss
.button-search-flat {
  .p-button {
    height: 2.85rem !important;
    padding: 0 $space-3 !important;
    background: transparent !important;
    border: 0 !important;
  }
}
```

Użycie: `<p-button class="button-search-flat">`.

#### 3. Anchor selector — co może być anchorem w global override

Selektor `.X .Y` jest "anchored" w `.X`. **`.X` MUSI być cross-cutting** (zewnętrzna klasa lub semantyczna globalna klasa modyfikator), nigdy nasz komponent / klasa scope'owana do naszego komponentu.

✅ DOBRZE — anchor jest cross-cutting:
```scss
.p-button .my-icon { ... }              // anchor: PrimeNG class
.p-sidebar-content { padding: 0; }       // anchor: PrimeNG class
.search-button-flat .p-button { ... }    // anchor: semantyczna klasa modyfikator
.button-grey:disabled { ... }            // anchor: globalna klasa modyfikator
.p-dropdown.invalid { ... }              // anchor: zewnętrzny tag + class
```

❌ ŹLE — anchor referuje nasz komponent:
```scss
.layout-flat .search-button { ... }      // .layout-flat to klasa hosta NASZEGO komponentu
app-our-component .child { ... }         // anchor to nasz komponent
app-search-bar.flat .child { ... }       // anchor to nasz komponent (qualifying type + class)
```

Globalne klasy w `_*.overrides.scss` mają być **cross-cutting**. Dla wariantowych styli zewnętrznych komponentów twórz **semantyczne klasy modyfikator** aplikowane bezpośrednio na docelowy element:

```scss
// partials/overrides/primeng/_button.overrides.scss
.search-button-flat {
  .p-button {
    height: 100% !important;
    padding: 0 $space-3 !important;
    background: transparent !important;
    border: 0 !important;
  }
}
```

Aplikacja conditionally w komponencie:
```html
<p-button class="search-button" [class.search-button-flat]="flatLayout">
```

#### Stylelint `selector-no-qualifying-type`

Projekt monopolex (i mops) blokuje selektory typu `tag.class` (np. `app-foo.bar`). Pisz `.bar .child` — klasy są dystynktywne.

#### 4. Klasa na hoście + `:host.X` w komponencie (gdy wariant lokalny, NIE dotyka PrimeNG)

Jeśli stylowanie wariantowe dotyczy LOKALNYCH klas komponentu (nie PrimeNG/Material), aktywuj wariant przez klasę na hoście:

```html
<!-- parent.html -->
<app-search-bar class="layout-flat" />
```

```scss
// search-bar.component.scss
:host.layout-flat {
  .search-input {
    border: 0;
    padding: 0;
  }
}
```

`:host.X` to standardowy Angular ViewEncapsulation Emulated — działa bez ng-deep bo dotyka lokalnych klas component-scoped.

#### 5. @Input + @HostBinding (gdy wariant musi propagować przez children)

Gdy variant musi być rozprowadzony przez kilka komponentów (parent → child → grandchild), użyj @Input + @HostBinding zamiast :host-context():

```ts
@Component({ ... })
export class SearchBarComponent {
  @Input() flatLayout = false
  @HostBinding('class.layout-flat') get hostClassFlat(): boolean {
    return this.flatLayout
  }
}
```

Plus propagacja do dziecka:
```html
<!-- search-bar.html -->
<app-suggestions-panel [class.layout-flat]="flatLayout" />
```

Plus child SCSS:
```scss
// suggestions-panel.component.scss
:host.layout-flat { ... }
```

Mops wzorzec — żaden `:host-context()` w kodzie, propagacja przez @Input + class binding.

Pierwsze (`[class.layout-flat]`) — propaguje TYLKO klasę CSS, item nie potrzebuje @Input. Mniej boilerplate gdy item nie potrzebuje wiedzieć o variantcie w TS.

Drugie (`[flatLayout]`) — pełny @Input pattern, item może reagować w TS (jeśli logika potrzebuje), `@HostBinding` automatycznie dodaje klasę.

#### 6. Placeholder `%name` + `@extend`

Reużywalny fragment stylu wielokrotnie → definiuj w `partials/placeholders/` i ekstenduj w komponencie:

```scss
// partials/placeholders/_misc.placeholders.scss
%box-shadow-none {
  &:hover { box-shadow: none !important; }
  &:focus { box-shadow: none !important; }
}
```

Użycie: `@extend %box-shadow-none`.

### Decyzja — który pattern wybrać

| Sytuacja | Pattern |
|---|---|
| Globalny wariant PrimeNG (reużywalny) | #1 lub #2 (klasa modyfikator) |
| Wariant kontekstowy (tylko w jednym miejscu), dotyka PrimeNG | #3 (parent-scoped override) |
| Wariant LOKALNY (nie dotyka PrimeNG), prosty | #4 (klasa na hoście + `:host.X`) |
| Wariant propagujący przez kilka komponentów | #5 (@Input + @HostBinding) |
| Reużywalny fragment stylu | #6 (placeholder + @extend) |

### `:host-context()` — preferuj jawną propagację, last resort

Mops używa ZERO `:host-context()`. Pattern do unikania bo:
- **Magic ancestor lookup** — komponent zachowuje się inaczej w zależności od "gdzieś wyżej w DOM" jest klasa
- **Implicit zależność** — komponent reaguje na ancestor którego sam nie deklaruje
- **Łamanie SRP** — niepublic kontrakt z ancestor niewidoczny w API

Preferowana alternatywa: propagacja przez @Input + class binding (patrz pattern #5).

**`:host-context()` używaj TYLKO gdy** propagacja przez parent HTML jest niemożliwa (np. komponent renderowany przez `ng-content` projection z nieznanego miejsca).

Przykład **akceptowalny** (rzadkie):
```scss
:host-context(.dark-theme) { ... }
```

Przykład **NIEakceptowalny** — gdy parent HTML jest pod twoją kontrolą:
```scss
// ŹLE
:host-context(.layout-flat) { ... }
// PRAWIDŁOWO: parent dodaje [class.layout-flat]="flatLayout" do item HTML
```

### Anty-wzorce (NEVER)

- `::ng-deep` w komponencie — **TWARDY ZAKAZ** (użyj pattern #3)
- `:host ::ng-deep .p-button { ... }` — anti-pattern (użyj #3)
- Klasa na PrimeNG hoście z magicznym znaczeniem bez globalnego override (`<p-button class="my-custom">` bez `.my-custom` w `_button.overrides.scss`)
- Inline `style="..."` w komponencie targetujący PrimeNG/Material

## Ikony

- **mat-icon** używa `[fontIcon]="..."` z material-icons / material-symbols
- **PrimeIcons** używa `icon="pi pi-..."` w p-button (input `icon`)
- Konwencja: mat-icon poza p-button (eg. inline w treści, w kafelkach), PrimeIcons w p-button (`<p-button icon="pi pi-arrow-left" />`)
- Sprawdzaj co projekt już używa zanim wprowadzisz inny zestaw

## SCSS — jednostki

**Decyzja jednostki = decyzja kontekstowa**. Wybierz tak:

| Jednostka | Kiedy używać | Przykłady |
|---|---|---|
| **Zmienna `$space-X` / `$spacing-*`** | padding, margin, gap — ZAWSZE jeśli pasuje | `padding: $space-3`, `margin: $spacing-default` |
| **`rem`** | width / height KONTENERA Z TEKSTEM ustawianego ręcznie | `width: 20rem` (okienko treści), `min-height: 4rem` (przycisk) |
| **`em`** | typografia względna (pierwsza litera, tag inline) | `font-size: 1.2em` |
| **`px`** | rozmiar wizualny BEZ tekstu — obrazki, ikony, granice, wymiary stałe | `width: 24px` (ikona), `border: 1px solid`, `width: 300px` (avatar) |
| **`%`** | layout proporcjonalny | `width: 100%`, `max-width: 50%` |

### Twarde NEVER (hook to blokuje)

- **NIGDY `vh`/`vw`/`svh`/`lvh`/`dvh`** — problemy mobile + safe-area + scroll

### Pierwszeństwo — drabinka decyzji

1. **Czy istnieje pasująca zmienna `$space-X` / `$spacing-*` / `$padding-*` / `$font-size-*` / `$color-*` / `$border-*`?** → użyj jej.
2. **Nie ma zmiennej, kontener z tekstem, wymiar ręcznie ustawiany?** → `rem` (1rem = 16px).
3. **Nie ma zmiennej, wymiar BEZ tekstu (ikona/obrazek/border)?** → `px`.
4. **Layout proporcjonalny?** → `%`.
5. **Typografia w inline kontekście (rzadkie)?** → `em`.

### Wymóg: ZAWSZE zmienne

- Kolory: `$color-bright`, `$color-dark-secondary`, etc. — NIGDY raw hex w komponencie (raw hex tylko w `vars/_color.vars.scss`)
- Border-radius: `$border-radius-very-small`, `$border-radius-small` itp.
- Font-weight: `$font-weight-normal`, `$font-weight-bold` (descriptive, nie 400/700)
- Wyjątek: konkretne unique kolory (np. brand gradient stops) — trzymane w `$color-*-gradient` zmiennych, NIE inline

## SCSS — naming klas

- **Flat names, bez parent prefix**:
  - TAK: `.icon`, `.title`, `.footer`, `.header`
  - NIE: `.overview-icon`, `.overview-footer-title`, `.card-header`
- **Precision prefix tylko przy realnej kolizji**:
  - `.footer-icon` (gdy istnieje `.icon` na top-level i drugi `.icon` w `.footer` różnie się stylują) — OK
- HTML mirror SCSS — `<div class="icon">`, `<div class="footer-icon">`, NIE BEM chain

### ZAKAZ `--` (BEM modifier syntax) w nazwach klas

**Twarda reguła**: NIGDY nie używaj `--` w nazwach klas SCSS. Klasa NIE może zawierać `--`.

❌ ŹLE:
```scss
.suggestions-panel--wide { ... }
.section-action--mobile { ... }
.button--disabled { ... }
```

✅ DOBRZE — lokalne klasy modifier semantyczne:
```scss
.wide { ... }           // modifier dla .suggestions-panel — dodawany [class.wide]
.mobile-only { ... }    // modifier "tylko na mobile"
.large { ... }          // modifier rozmiaru
```

BEM `--` niespójne z projektem (nie używamy block__element), długie, powtarza nazwę komponentu. `class="suggestions-panel wide"` mówi to samo krócej.

### Lokalne vs globalne klasy — DWA RÓŻNE filozofie naming

**Zasada NADRZĘDNA**:
- **Lokalne klasy mówią CO TO JEST** (rola, odpowiedzialność elementu w komponencie)
- **Globalne klasy mówią JAKIE TO JEST** (wariant, modyfikator, wygląd — niezależnie od kontekstu)

#### Klasy LOKALNE (w `*.component.scss`)

**Pattern**: rzeczownikowa nazwa opisująca **ROLĘ / odpowiedzialność** elementu. NIE typ. NIE wariant.

**Dwie podkategorie lokalnych**:

1. **Base klasa** (samodzielna, główna klasa elementu) — opisuje co to jest:
   - ✅ `.search-button`, `.exit-button`, `.submit-action`, `.cart-icon`, `.loading-ellipsis`, `.section-action`, `.footer-count`
   - ✅ `.button`, `.icon`, `.title` — gdy jest jeden w komponencie, sam typ wystarczy jako "rola"
   - ❌ `.wide-button`, `.large-button`, `.blue-icon` — to wariant, nie rola
   - **Wyjątek**: gdy typ JEST opisem roli — `.primary-action` (rola: primary call to action) jest OK

2. **Modifier klasa** (dopinana do base przez `[class.X]` lub `class="base modifier"`) — opisuje stan/wariant:
   - ✅ `.wide`, `.large`, `.collapsed`, `.disabled`, `.active`, `.mobile-only`, `.expanded`
   - BEZ prefiksu nazwy komponentu — komponent jest scope'm przez Angular ViewEncapsulation.
   - Modifier ZAWSZE dopinany do base klasy, nigdy samodzielnie.

Rola jest **stabilna** (button do search zawsze będzie do search). Wariant się **zmienia**. Naming po roli = mniej refactor.

#### Klasy GLOBALNE (w `partials/overrides/`, `partials/utilities/`)

**Pattern**: `<co>-<jakie>-<wariant>` — opisuje **JAKIE TO JEST** (wariant elementu cross-component).

- ✅ `.button-wide`, `.button-grey`, `.button-transparent`, `.button-inverted`, `.button-flat`, `.button-no-border`
- ✅ `.icon-blue`, `.text-truncate`
- Pattern: `<noun>` (typ elementu) + `<modifier>` (wariant). Może być więcej członów: `.button-grey-large`.

Globalne klasy MAJĄ prefix `<noun>` bo działają **cross-component** — `.button-grey` mówi "wszelki `<p-button>` z tą klasą ma grey background". Bez prefiksu (`.grey`) kolizja z lokalnymi modyfikatorami.

#### Przykład — porównanie

```scss
// search-bar.component.scss — LOKALNE
.search-bar {              // base — co to jest: search bar
  display: flex;
}

.search-input {            // base — co to jest: input do search (rola, nie typ)
  width: 100%;
}

.search-button {           // base — co to jest: button do search
  background: $color-bright;
}

.suggestions-panel {       // base — co to jest: panel z sugestiami
  border: 1px solid $color-bright-tertiary;
}

.wide {                    // modifier — dopinany do .suggestions-panel
  min-width: 56rem;
}

.mobile-only {             // modifier — dopinany do .section-action
  @include lg(min) {
    display: none;
  }
}

// partials/overrides/primeng/_button.overrides.scss — GLOBALNE
.button-grey {             // wariant cross-component: button szary
  ::ng-deep .p-button {
    background: $color-grey !important;
  }
}

.button-flat {             // wariant cross-component: button bez ramki/shadow
  ::ng-deep .p-button {
    box-shadow: none !important;
    border: 0 !important;
  }
}
```

```html
<!-- LOKALNE base + globalna modifier -->
<button class="search-button button-grey">Search</button>
<!-- ↑ base "search-button" (co robi) + global "button-grey" (jak wygląda) -->

<!-- LOKALNE base + lokalna modifier dopinana conditionally -->
<div class="suggestions-panel" [class.wide]="hasProducts">

<!-- LOKALNE base + lokalna modifier -->
<button class="section-action mobile-only">Clear</button>
```

#### Decyzja — pisząc nową klasę, zapytaj:

1. **Jaką rolę pełni ten element w komponencie?** → to twoja **base** klasa (`search-button`, `exit-button`, `loading-ellipsis`).
2. **Czy klasa to wariant base — szeroki/duży/mobilny/disabled?** → **modifier** klasa (`wide`, `large`, `mobile-only`, `disabled`) dopinana do base.
3. **Czy wariant powtarza się w wielu komponentach (cross-component)?** → wynieś do **global** (`partials/overrides/`) jako `<noun>-<modifier>` (np. `.button-wide`).
4. Jeśli kuszony żeby napisać `.wide-button` lokalnie — **STOP**. Nazwij po roli (`.search-button`), a "wide" przenieś do osobnej modifier-klasy (`.wide` lub global `.button-wide`).
5. **Czy ta lokalna klasa będzie robić TYLKO `@extend %placeholder` lub 1–2 property override globalnej klasy?** → **STOP, NIE wprowadzaj jej**. Użyj globalnej klasy bezpośrednio w HTML; lokalny override w SCSS targetuje TĘ globalną klasę (patrz niżej).

#### Klasa lokalna jako wrapper na `@extend` / drobny override — anti-pattern

**Twarda reguła**: jeśli lokalna klasa istnieje TYLKO po to żeby zrobić `@extend %placeholder` albo `1–2 property` override globalnej klasy, **NIE wprowadzaj jej**. Element dostaje globalną klasę bezpośrednio w HTML, lokalny override w komponentowym SCSS targetuje globalną klasę. Angular ViewEncapsulation scope'uje override do komponentu (`.global-klasa[_ngcontent-X]`) — inne użycia globalnej klasy są nietknięte.

Reguła "lokalne klasy nazywają ROLĘ" (`.search-button`, `.exit-button`) zakłada że klasa **zarabia na swoje istnienie własnym stylowaniem**. Klasa robiąca wyłącznie `@extend` lub drobny override **nie zarabia** — dodaje szum w HTML (`class="auth-section-separator"` zamiast `class="divider-vertical"`) bez wartości semantycznej, której globalna klasa już nie niesie.

❌ ŹLE — lokalna klasa-wrapper na `@extend` + override:

```html
<div class="auth-section-separator"></div>
```

```scss
.auth-section-separator {
  @extend %divider-vertical;
}

@include md {
  .auth-section-separator {
    width: 100%;
    height: 1px;
  }
}
```

✅ DOBRZE — globalna klasa w HTML, lokalny override w SCSS:

```html
<div class="divider-vertical"></div>
```

```scss
@include md {
  .divider-vertical {
    width: 100%;
    height: 1px;
  }
}
```

❌ ŹLE — lokalna klasa-wrapper na sam margin override:

```html
<div class="divider-vertical section-divider"></div>
```

```scss
.section-divider {
  margin: 0 $space-3;
}
```

✅ DOBRZE — override targetuje globalną klasę bezpośrednio:

```html
<div class="divider-vertical"></div>
```

```scss
.divider-vertical {
  margin: 0 $space-3;
}
```

❌ ŹLE — redundant `@extend` w komponencie gdy istnieje globalna klasa o tej samej nazwie:

```scss
// _layout.globals.scss już ma: .divider { @extend %divider }
.divider {
  @extend %divider;                       // ← redundant — globalna .divider już to robi
  width: calc(100% + $space-3);
  margin: 0;
}
```

✅ DOBRZE — sam override, globalna `.divider` aplikuje `%divider` przez kaskadę:

```scss
.divider {
  width: calc(100% + $space-3);
  margin: 0;
}
```

#### Kiedy lokalna klasa MA sens (test odwrotny)

| Lokalna klasa wnosi... | Lokalna klasa? |
|---|---|
| Własny set właściwości (kolor, layout, typografia, hover/focus, struktura) | TAK — nazwa po roli (`.search-button`, `.cart-icon`) |
| `@extend %placeholder` + **3+ overrides** zmieniających istotę elementu | Granica — rozważ czy element naprawdę różni się od globalnej, czy to inny placeholder |
| TYLKO `@extend %placeholder` | NIE — użyj globalnej klasy w HTML |
| TYLKO `1–2 property` override globalnej | NIE — użyj globalnej klasy w HTML, override targetuje globalną |
| Redundant `@extend %X` gdy istnieje globalna `.X` | NIE — usuń `@extend`, override sam wystarcza |

#### Dlaczego to ważne

- Lokalna klasa po roli **bez własnego stylowania** to "wrapper indirection" — czytelnik patrzy na `.section-divider` i myśli "co to za specjalny divider?" Otwiera SCSS, widzi `margin: 0 $space-3` i traci czas.
- HTML powinien mieć **klasy które niosą informację**, a nie placeholdery semantyki ("to jest divider w sekcji" — tak, widzę, jest w sekcji bo TAM JEST w DOM).
- Single source of truth: jedna globalna `.divider-vertical` w HTML jasno mówi "ten element to globalny pionowy divider". Lokalna nazwa sugeruje że to **coś innego** niż globalny, co prowadzi do mental load.

## SCSS — `:host` tylko gdy konieczne, max 1 blok per plik

**Twarda reguła**: `:host` w `.component.scss` używasz **wyłącznie tam gdzie musisz** — stylowanie samego host elementu lub jego wariantów. Klasy lokalne komponentu (`.foo`, `.bar`) są na **poziomie modułu**, NIE wrappowane w `:host`.

**Plus**: **dokładnie jeden** blok `:host { ... }` per plik. Warianty hosta (`.layout-flat`, `.disabled` itd.) — jako nested `&.X` wewnątrz tego jednego `:host`.

❌ ŹLE — dwa osobne `:host`:
```scss
:host {
  display: block;
}

.product-hint-item { padding: $space-2 $space-3; }
.thumbnail { width: 3rem; }

:host.layout-flat {                // ← drugi :host na końcu
  .product-hint-item { padding: $space-3; }
}
```

❌ ŹLE — wszystko owrappowane w `:host` (over-wrapping):
```scss
:host {
  display: block;

  .product-hint-item { ... }       // ← niepotrzebny wrapper
  .thumbnail { ... }               // ← niepotrzebny wrapper

  &.layout-flat {
    .product-hint-item { ... }
  }
}
```

✅ DOBRZE — `:host` tylko dla samego hosta + warianty, klasy lokalne top-level:
```scss
:host {
  display: block;

  &.layout-flat {
    .product-hint-item { padding: $space-3; }
    .thumbnail { width: 3.5rem; }
  }
}

.product-hint-item {
  padding: $space-2 $space-3;
}

.thumbnail {
  width: 3rem;
}
```

✅ DOBRZE — komponent bez base host styling, tylko warianty:
```scss
:host {
  &.layout-flat {
    .product-hint-item { padding: $space-3; }
  }
}

.product-hint-item {
  padding: $space-2 $space-3;
}
```

### Why

- **`:host` jest specjalny — tylko dla host elementu**. Wrappowanie wszystkich klas w `:host` dodaje szum bez znaczenia (Angular view encapsulation już ogranicza scope klas do komponentu). Zwiększa specificity bez korzyści.
- **Klasy top-level są krótsze** — bez wcięcia na 2-3 poziomy, łatwiej skanować plik wzrokiem.
- **Jeden `:host`** — wszystkie host-specific style (base + warianty) razem. Nie szukasz `:host.foo` na końcu pliku po przewinięciu 200 linii klas lokalnych.
- **`&.X` zamiast osobnego `:host.X`** — Sass nesting wyraża jaśniej że to wariant tego samego host elementu.

### Decyzja — czy potrzebuję `:host` block?

| Sytuacja | Użyj `:host`? |
|---|---|
| Stylowanie host elementu (`display`, `position`, `padding`) | TAK |
| Wariant host elementu przez klasę (`.layout-flat`, `.disabled` na hoście) | TAK (`&.X` w środku) |
| `@HostBinding` propaguje class do hosta i ten class zmienia layout | TAK (`&.X`) |
| Stylowanie zwykłej klasy wewnątrz komponentu | NIE — pisz top-level `.class { ... }` |
| `@keyframes` | NIE — to global, MUSI być top-level (poza wszystkim) |

### Wyjątki

- `@keyframes` — global at-rule, ZAWSZE top-level, nigdy w `:host`.
- `:host-context()` — jeśli używany (rzadko, last resort dla absolutnie niemożliwej propagacji), preferowane w środku `:host { :host-context(...) { ... } }`.

### Stary kod — kiedy migrować

- **Nowy plik / nowy komponent**: stosuj od razu.
- **Edycja istniejącego pliku, którego już dotykasz**: zrefactoruj przy okazji.
- **Plik którego nie edytujesz**: zostaw — migracja bez sensu, plik wygląda jak wygląda dopóki ktoś go nie tknie.

## Funkcje helper — gdzie żyją

**Twarda reguła**: w plikach `.component.ts`, `.service.ts`, `.directive.ts`, `.pipe.ts` — **ZAKAZ plain function declarations / function exports na poziomie modułu** (poza klasą).

❌ ŹLE — plain function obok komponentu:
```ts
@Component({...})
export class FooComponent {
  view = createInitialView()
}

function createInitialView(): View { ... }  // ← module-scope plain function
```

❌ ŹLE — export plain function z component file:
```ts
// w foo.component.ts
export function buildSomething(x: number): string { ... }
```

✅ DOBRZE — prywatna metoda klasy (gdy używana tylko w tej klasie):
```ts
@Component({...})
export class FooComponent {
  view: View

  constructor(...) {
    this.view = this.createInitialView()
  }

  private createInitialView(): View { ... }
}
```

✅ DOBRZE — osobny helper file **jako klasa** (default: **instance methods + DI**):
```ts
// helpers/view-builder.helper.ts
import { Injectable } from '@angular/core'

@Injectable()
export class ViewBuilderHelper {
  buildInitial(): View { ... }

  merge(a: View, b: View): View { ... }

  private normalize(input: string): string { ... }
}
```

Użycie: inject przez DI + wywołanie przez instance:
```ts
constructor(private viewBuilderHelper: ViewBuilderHelper) {}

private build(): View {
  return this.viewBuilderHelper.buildInitial()
}
```

❌ ŹLE — helper file z plain function exports:
```ts
// helpers/view-builder.helper.ts
export function buildInitial(): View { ... }       // ← module-scope plain function
export function merge(a: View, b: View): View { ... }
```

✅ DOBRZE — service method (gdy wymaga DI lub cross-component state).

### Decyzja — gdzie umieścić helper

| Sytuacja | Lokalizacja |
|---|---|
| Używana TYLKO w tej klasie, brak DI, prosta | **private method** w klasie |
| Używana w >1 komponencie, czysta utility (np. `array.toggle`, `component.unsubscribe`) | **`helpers/<nazwa>.helper.ts`** jako `class XxxHelper` z `static` methods |
| Używana w >1 komponencie, logika **domenowa** lub złożona (np. merging suggestions, highlighting text) | **`helpers/<nazwa>.helper.ts`** jako `class XxxHelper` z **instance methods + `@Injectable()` + DI** |
| Wymaga DI innych services / cross-component state | **`<nazwa>.service.ts`** + `@Injectable()` |

### Static vs instance methods — kiedy co

**Static methods (`ArrayHelper`, `ComponentHelper`, `ConverterHelper`)**:
- Pure utility — bez zależności, bez state, bez kontekstu domenowego
- Wywoływane bezpośrednio: `ArrayHelper.toggle(...)`
- NIE wymagają providera ani DI

**Instance methods + DI (`ApiHelper`, `ObjectHelper`, `SearchSuggestionsHelper`)** ← **DOMYŚLNE**:
- Logika domenowa, biznesowa, złożona
- Mogą w przyszłości potrzebować innych services przez DI bez zmiany konsumentów
- Łatwiejsze do mockowania w testach (przez `MockProvider`)
- Wywoływane przez `this.helper.method(...)`
- WYMAGAJĄ providera w odpowiednim module (`core.module.ts` lub feature module)

**Default**: gdy wątpliwość — **instance + DI**. Łatwiej skalować.

### Helper class — konwencje

- **Nazwa pliku**: `<nazwa>.helper.ts` (kebab-case)
- **Nazwa klasy**: `<Nazwa>Helper` w PascalCase (`ArrayHelper`, `SearchSuggestionsHelper`, `ComponentHelper`)
- **Decorator**: `@Injectable()` na klasie (projektowa konwencja, OBA wzorce)
- **Metody (instance)**: wywołania wewnętrzne przez `this.method(...)`
- **Metody (static)**: wywołania wewnętrzne przez pełną nazwę klasy `ClassName.method(...)` (nie ma `this` w static)
- **Provider**: instance helpery WYMAGAJĄ provider w `providers: [...]` modułu — `core.module.ts` dla core helpers, feature module dla feature-specific
- **NIGDY top-level plain functions** w helper file — wszystko wewnątrz klasy
- **Test pattern (instance)**: `createServiceFactory({ service: XxxHelper })` + `helper = spectator.service`
- **Test pattern (static)**: bezpośrednie wywołania `XxxHelper.method(...)` bez factory

### Why

- Plain function na poziomie modułu w pliku komponentu **rozszerza publiczne API pliku** o coś czego nie powinno tam być (komponent eksportuje tylko Component class).
- Testy importują plik — plain functions stają się accidentalnie publicznym surface'm.
- Linter (`@typescript-eslint/no-unused-vars`, `import/no-unused-modules`) nie zawsze łapie martwe helpery.
- Reuża wymaga MOVE'u i tak — lepiej od razu w osobnym pliku.
- Private method w klasie jest **czysta** semantycznie: "ten kod należy do tej klasy".

### Wyjątki

- Type guards / discriminator predicates w `*.guard.ts` / `*.predicate.ts` — OK
- Utility types (`export type Foo = ...`) — OK, to NIE funkcja
- Const tokens / configuration (`export const TOKEN = new InjectionToken(...)`) — OK

## Subscriptions — group unsubscribe

**Twarda reguła**: gdy komponent ma **więcej niż jedną subscription** do posprzątania w `ngOnDestroy`, **grupuj je w jednym wywołaniu** `ComponentHelper.unsubscribe(...)`. Każde subskrypcja jako osobny argument.

❌ ŹLE — wiele osobnych wywołań:
```ts
ngOnDestroy(): void {
  ComponentHelper.unsubscribe(this.subscriptionShowUserMenu)
  ComponentHelper.unsubscribe(this.subscriptionUser)
  ComponentHelper.unsubscribe(this.subscriptionUserInProgress)
}
```

✅ DOBRZE — jedno wywołanie z wieloma argumentami:
```ts
ngOnDestroy(): void {
  ComponentHelper.unsubscribe(
    this.subscriptionShowUserMenu,
    this.subscriptionUser,
    this.subscriptionUserInProgress
  )
}
```

✅ DOBRZE — jedna subscription, jedno wywołanie:
```ts
ngOnDestroy(): void {
  ComponentHelper.unsubscribe(this.subscriptionState)
}
```

### Why

- `ComponentHelper.unsubscribe(...subscriptions)` przyjmuje variadic args — projektowy helper jest do tego stworzony.
- Mniej linii kodu, jedna oś pracy `ngOnDestroy` — czytelne intent: "posprzątaj WSZYSTKO".
- Refactor (dodawanie/usuwanie subscription) wymaga edycji tylko jednej listy argumentów, nie kilku linii.
- Mniejsze ryzyko zapomnienia o unsubscribe — wszystkie sub w jednym widoku.

## Component composition — emisja zdarzeń z dziecka

- **Lista należy do dziecka — emituje selekcję, nie operacje CRUD**
- Wzorzec: child renderuje listę, emituje `(selected)` event z wybranym elementem **lub** `undefined` (deselekcja)
- NIE: osobne `(itemAdded)`, `(itemUpdated)`, `(itemDeleted)` propagowane przez parent
- **Why**: parent nie powinien znać wewnętrznych operacji dziecka — tylko "co użytkownik wybrał". "Piekło eventowe" (event hell): trzy handlery per CRUD verb, trzy switch'e, mutation logic w trzech warstwach.
- **How to apply**: gdy projektujesz komunikację parent↔child z listą, zacznij od pojedynczego event "selected: T | undefined". Child sam zarządza swoją listą wewnętrznie i emituje selected na: init (auto-select first), user pick, add (select new), edit (select updated), delete-of-selected (next or undefined).

### Liść w `*ngFor` rodzica — emituj SYGNAŁ, nie element który rodzic już ma

**Twarda reguła**: gdy **rodzic** renderuje listę przez `*ngFor` i przekazuje element do dziecka przez `[item]="item"` (lub `[text]`, `[data]`…), a dziecko emituje selekcję/akcję — dziecko emituje **sygnał** (`EventEmitter<void>`), **NIE element**. Payload podaje rodzic ze swojego scope `*ngFor`. Re-emit elementu, który rodzic już trzyma, to **martwy kod**.

✅ DOBRZE — dziecko sygnalizuje, rodzic podaje element:
```ts
// child
@Output() selected = new EventEmitter<void>()
onClick(): void {
  this.selected.emit()
}
```
```html
<!-- parent *ngFor -->
<app-item [item]="item" (selected)="itemSelected.emit(item)" />
```

❌ ŹLE — dziecko re-emituje element, który rodzic ma w `*ngFor`:
```ts
@Output() selected = new EventEmitter<Item>()
onClick(): void {
  this.selected.emit(this.item)
}
```
```html
<app-item [item]="item" (selected)="itemSelected.emit($event)" />
```

**Rozróżnienie z regułą wyżej** (to NIE sprzeczność — to dwa różne przypadki):

| Przypadek | Kto zna element? | Co emituje dziecko |
|---|---|---|
| **Child-lista** (dziecko renderuje całą listę wewnętrznie) | rodzic NIE zna — dziecko zarządza listą | **element** (`selected: T \| undefined`) — patrz reguła wyżej |
| **Liść w `*ngFor` rodzica** (rodzic renderuje listę, `[item]` w dół) | rodzic ma `item` w scope | **sygnał** (`EventEmitter<void>`) |

**Zasada nadrzędna**: sygnał płynie w górę dokładnie tak daleko, jak sięga wiedza o elemencie. Liść→rodzic-z-listą = **sygnał** (rodzic zna item). Rodzic-z-listą→dziadek-który-NIE-renderuje-listy = **element** (dziadek nie ma innego źródła — np. potrzebuje go do `getLink`/nawigacji). NIE kasuj emitu elementu tam, gdzie odbiorca naprawdę go nie zna — naiwna reguła/hook „nigdy nie emituj itemu" błędnie oflaguje ten poprawny przypadek.

**Why**: `(selected)="x.emit($event)"` gdzie `$event` to dosłownie `item` z tego samego `*ngFor` — duplikuje referencję, którą rodzic już trzyma. Dziecko typowane na konkretny `Item` jako output sztucznie sprzęga liść z typem domeny, mimo że niesie zero informacji ponad „kliknięto mnie". Test propagacji jest też **mocniejszy** gdy rodzic podaje `item` (weryfikuje, że bierze właściwy z `*ngFor`), zamiast ślepo przepuszczać `$event`.

## Structural directives — TYLKO na `<ng-container>`

**Twarda reguła**: `*ngIf`, `*ngFor`, `*ngSwitch` (i nowoczesne odpowiedniki `@if`, `@for`, `@switch` w mops) **MUSZĄ** być na `<ng-container>`. NIGDY na normalnym tagu (`<div>`, `<section>`, custom Angular component).

✅ DOBRZE:
```html
<ng-container *ngIf="visible">
  <div class="wrapper">
    <h3>Title</h3>
    <app-content />
  </div>
</ng-container>

<ng-container *ngFor="let item of items; trackBy: trackById">
  <app-item [item]="item" />
</ng-container>
```

❌ ŹLE:
```html
<div *ngIf="visible" class="wrapper">  <!-- struktura DOM zależy od warunku -->
  <h3>Title</h3>
</div>

<app-item *ngFor="let item of items" [item]="item" />  <!-- directive miesza z input -->
```

**Wyjątek**: Nie ma wyjątków. Hook blokuje.

## HTML templates — self-closing tags

- **Gdy element nie ma children — używaj self-closing form `<tag />`, NIE `<tag></tag>`**
  - TAK: `<my-component [input]="value" />`, `<router-outlet />`, `<input type="text" />`
  - NIE: `<my-component [input]="value"></my-component>`, `<router-outlet></router-outlet>`
- **Spacing**: `<tag />` ze spacją przed slashem (Angular team convention)
- **Kiedy NIE self-closing**:
  - Element ma children / content projection → jawne `</tag>`
  - Standardowe HTML non-void elements (`<div>`, `<span>`, `<p>`, `<section>`) — MUSZĄ mieć jawne `</tag>`. `<div />` jest niepoprawnym HTML. Self-closing dotyczy tylko: Angular components/directives (Angular 15.1+) i void HTML elements (`<input>`, `<br>`, `<img>`, `<hr>`, `<meta>`, `<link>`).
- **EGZEKWUJ NAWET GDY SĄSIEDZTWO ROBI INACZEJ.** Wyjątek: projektowy `CLAUDE.md` z **explicite zapisanym** zakazem self-closing.
- **Najczęściej dotyczy**: `<p-button .../>`, `<p-divider .../>`, `<mat-icon .../>`, `<router-outlet />`, `<app-* .../>`, void HTML (`<input />`, `<br />`).

### Line length — kiedy one-liner, kiedy multi-line

Bazowy limit: 90 znaków (prettier `printWidth: 90`). Strefa elastyczna: do ~120 znaków (≈ +33%) MOŻNA zostawić one-liner gdy poprawia czytelność.

**One-liner gdy element ma 2-4 krótkie atrybuty i mieści się w ~120 znaków**:
```html
<app-layout-image class="thumbnail" [img]="item.img" [size]="imageSize" />
<app-product-rating [rating]="item.rating" [size]="ratingSize" />
<router-outlet />
```

**Multi-line gdy długość > ~120 znaków LUB > 4 atrybutów** — każdy atrybut w osobnej linii, `/>` w osobnej:
```html
<app-search-suggestions-phrase-item
  [class.layout-flat]="flatLayout"
  [item]="item"
  [variant]="searchSuggestionPhraseItemType.RECENT"
  (selected)="phraseSelected.emit($event)"
  (removed)="phraseRemoved.emit($event)"
  data-testid="phrase-item"
/>
```

**Reguła decyzyjna**:
- ≤ 90 znaków → zawsze one-liner
- 90-120 znaków → one-liner JEŚLI czytelny; multi-line gdy dużo bindings
- \> 120 znaków → ZAWSZE multi-line
- Liczba atrybutów > 4 → multi-line nawet gdy by się zmieściło

## data-testid — egzekucja

- **Każdy** element interaktywny: button, input, link, select → `data-testid="<verb>-<noun>"` (np. `data-testid="submit-button"`, `data-testid="email-input"`)
- **Każdy** element kontekstowy używany w teście: container, message, list item → `data-testid` kebab-case
- W spec.ts query po nim ZAWSZE — to jest jedyna stabilna oś między HTML a testem

### Naming testid — opisuje CZYM JEST element

`data-testid` nazywa się tak jak element — tak jak klasa CSS na nim. NIGDY generyczne `trigger` / `container` / `wrapper` na rootcie komponentu.

**Root element komponentu** → `data-testid` = root klasa CSS komponentu:
- `<a class="category-hint-item" ... data-testid="category-hint-item">` ✅
- `<a class="category-hint-item" ... data-testid="trigger">` ❌ — nic nie mówi

**Inne elementy** → flat, krótkie nazwy odpowiadające temu czym są (zazwyczaj = klasa CSS):
- `<span class="name" data-testid="name">` ✅
- `<button class="show-all" data-testid="show-all">` ✅

**Bez parent prefix gdy nie ma kolizji** (jak SCSS — flat naming):

✅ `data-testid="submit-button"` (nie `search-bar-submit-button`)
❌ `data-testid="search-bar-submit-button"` — parent prefix bez powodu

Wyjątek: root element komponentu MA prefix bo jego nazwa = nazwa komponentu (`category-hint-item`). To nie parent prefix — to opis tego CZYM JEST root.

- **NIE dodawaj `data-testid` "na zapas".** Jeśli spec używa `spectator.query(SomeComponent)` (po typie), NIE dodawaj testid — query po typie wystarcza. Testid bez konsumenta w spec = martwy kod.
- **`data-testid` ZAWSZE jako OSTATNI atrybut elementu** — po wszystkich structural directives, bindings, klasach, stylach.
  - TAK: `<button class="primary" [disabled]="isLoading" (click)="submit()" data-testid="submit-button">`
  - NIE: `<button data-testid="submit-button" class="primary" [disabled]="isLoading" (click)="submit()">`

## Pre-flight przed edycją Angular code

Przed dotknięciem `.ts/.html/.scss/.spec.ts` w projekcie Angular ja muszę GŁOŚNO odpowiedzieć:

1. Jaka wersja Angulara? (sprawdzam `package.json` projektu)
2. Standalone czy NgModules? (sprawdzam istniejące komponenty obok)
3. Signals czy RxJS? (sprawdzam state management projektu)
4. Czy projekt używa `inject()` czy konstruktor injection?
5. Jakie path aliases? (sprawdzam `tsconfig.base.json` / `tsconfig.json`)
6. Spectator + ng-mocks — wymóg.
7. data-testid — wymóg dla każdego interaktywnego elementu.
8. SCSS — sprawdzam dostępne `$` zmienne w `partials/vars/` zanim wymyślę własne wartości.
9. Jednostki SCSS — drabinka decyzji wyżej.

Jeśli na którekolwiek nie znam odpowiedzi → NIE PISZĘ kodu, najpierw sprawdzam.
