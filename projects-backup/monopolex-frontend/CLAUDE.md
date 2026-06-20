# monopolex-frontend — reguły projektowe

> **Profil**: LEGACY. Angular 16 + NgModules + RxJS-first. Projekt utrzymaniowy — pisz NOWY kod w stylu istniejącego, NIE migruj do signals/standalone bez wyraźnej prośby.
>
> **Stack**: Angular 16, yarn, Karma + Jasmine, Cypress, PrimeNG 16, Angular Material 16, SSR (@nguniversal), MSAL Azure.

Reguły poniżej są **NADRZĘDNE** wobec globalnych w `~/.claude/rules/`. W razie konfliktu — wygrywa ten plik.

---

## Pre-flight checklist — WYPISZ przed każdą edycją kodu

```
[ ] NgModule deklaruje komponent (osobny <comp>.module.ts)?
[ ] Constructor injection z `private foo: Foo`?
[ ] *ngIf / *ngFor (NIE @if/@for — A16 nie wspiera)?
[ ] Subscription + manual unsubscribe w ngOnDestroy?
[ ] data-testid na każdym interaktywnym elemencie?
[ ] Path alias @components/@core/@shared/@ecommerce (nigdy ../..)?
[ ] Class name: <Feature><Category><Name>Component?
[ ] Karma syntax: toBeTrue/toBeFalse, jasmine.createSpy, .calls.reset()?
```

Jeśli wahasz się na którymkolwiek punkcie → przeczytaj sąsiedni komponent ZANIM piszesz.

---

## TWARDE WYMAGANIA (MUST)

### Komponenty

- **MUSI być NgModule** — każdy komponent ma `<comp>.module.ts` deklarujący i eksportujący go
- Selector prefix: `app-` (kebab-case)
- Klasa: `<Feature><Category><Name>Component` (np. `CartCouponsFormComponent`, `ProductDetailsComponent`)
- Plik komponentu: `<name>.component.ts` (kebab-case)

### Komunikacja komponentów — DZIAŁANIE WPROST (nie smart-parent / dumb-child)

**Monopolex NIE robi „mądry rodzic / głupie dziecko".** Komponent który wie co zrobić — robi to SAM, zamiast emitować event w górę do rodzica-orkiestratora. (To ODWROTNIE niż mops, gdzie robimy emit-up. Ta reguła **NADPISUJE** globalną `angular.md` „Component composition — emisja zdarzeń z dziecka" dla monopolexa.)

- **Liść z akcją nawigacyjną → nawiguje SAM.** Item produktu na klik → `router.navigateByUrl(...)` u siebie (ma już wstrzyknięty `ProductService.getLink`). Item kategorii analogicznie z `CategoryService`. NIE emituje `(selected)` w górę.
- **Komponent zarządzający danymi → robi to u siebie.** Item/panel fraz: dodanie/usunięcie recent + nawigacja do strony wyszukiwania — wprost przez serwis + router, bez `(phraseSelected)`/`(phraseRemoved)` do rodzica.
- **Efekt: rodzic (panel, search-bar) NIE ma `@Output()` nawigacyjnych ani handlerów-orkiestratorów.** Mniej boilerplate, każdy komponent samowystarczalny.

**Jedyny cross-cutting problem — zamykanie UI przy nawigacji** — rozwiązuje komponent WŁAŚCICIEL widoczności, nasłuchując router events (NIE orkiestracja z góry):
```ts
constructor(private router: Router, ...) {}

ngOnInit(): void {
  this.subscriptionNavigation = this.router.events
    .pipe(filter((event) => event instanceof NavigationEnd))
    .subscribe(() => {
      if (this.visible) {
        this.visible = false
      }
    })
}
```
- **Mobile menu**: nasłuch `NavigationEnd` → `setVisibility(false)` gdy widoczne.
- **Search panel** (`suggestionSearchPanelVisible` w search-bar): TEN SAM wzorzec → zamknij panel na `NavigationEnd`. Panel desktopowy też trwa nad nową stroną, więc to nie tylko mobile menu.
- **Pułapka same-URL — `NavigationEnd` NIE strzela na nawigację na TEN SAM URL** (`onSameUrlNavigation: 'ignore'`, default routera). `search()` / „show all" / klik frazy nawigują na `/search?searchPhrase=…`; będąc już tam z tą frazą → router ignoruje → brak eventu → panel/menu zostają otwarte. Klik produktu/kategorii idzie na INNY URL → tam `NavigationEnd` działa.
- **Rozwiązanie: sygnał DOMENOWY w serwisie, NIE łatanie per-akcja/per-klik.** `SearchSuggestionsService.pushRecent()` (woła go search-bar `search()`, panelowe „show all", klik frazy = „user ZATWIERDZIŁ wyszukiwanie") emituje `searchCommitted: Observable<void>`. Każdy WŁAŚCICIEL widoczności subskrybuje i zamyka SWOJE UI: search-bar → swój panel (`closePanel()`), sidebar → mobilne menu (`setVisibility(false)`). To domyka też same-URL, niezależnie od routera.
- **Każdy właściciel reaguje na DWA sygnały — oba domenowe/nawigacyjne, NIGDY na „klik gdziekolwiek w panelu":** `NavigationEnd` (nawigacja na inny URL: produkt/kategoria) + `searchCommitted` (zatwierdzenie wyszukiwania). Dzięki temu `clear-recent` / `remove-recent` (nie nawigują, nie commitują) NIE zamykają panelu — automatycznie, bez wyjątków/`stopPropagation`.
- **NIE rób hacków:** ani `(click)="closePanel()"` na wrapperze panelu (zamyka też na klik w martwą przestrzeń i na clear-recent), ani `closePanel()`/`setVisibility(false)` wklejone imperatywnie w `search()`. Zamknięcie = REAKCJA właściciela na sygnał domenowy, nie imperatyw w akcji ani nasłuch kliknięć. **Dotykanie serwisu (dodanie `searchCommitted`) to legalna część implementacji feature'u, nie „globalna zmiana".**

**Wyjątek (kiedy WOLNO emitować w górę):** gdy dziecko NAPRAWDĘ nie ma jak wykonać akcji samo (brak dostępu do serwisu/kontekstu, akcja należy do rodzica). Domyślnie jednak — działanie wprost.

**Rodzic-kontener NIE śledzi stanu panelu dziecka.** Panel sugestii jest **absolute overlay** (patrz „Panele / dropdown — pozycjonowanie" niżej), więc nakłada się na treść i sidebar NIE musi wiedzieć czy panel jest otwarty — zero `@Output() ...VisibleChange`, zero `[class.hidden]` na `menu-body`, zero pola panel-visible w rodzicu. (Historia decyzji: było in-flow `position: static` + chowanie `menu-body` + `@Output suggestionSearchPanelVisibleChange` → **odrzucone**, bo to był UNIKAT niespójny ze standardem projektu i zbędne sprzężenie parent↔child. Overlay = panel zachowuje się identycznie wszędzie, kontener go nie zna.)

**Anti-pattern (NIGDY): template ref do publicznego pola dziecka** — `#searchBar` + `[class.hidden]="searchBar.suggestionSearchPanelVisible"` w HTML rodzica = sięganie do publicznego pola komponentu przez template ref. Jeśli rodzic NAPRAWDĘ musi znać stan dziecka (rzadkie, gdy overlay niemożliwy) → `@Output` notyfikujący zmianę stanu, NIGDY template ref.

### Panele / dropdown / overlay — pozycjonowanie

**Standard projektu: panel pojawiający się pod inputem/triggerem = `position: absolute` overlay, nigdy in-flow.** Tak robi WSZYSTKO w projekcie:

| Element | Plik | `position` | `z-index` |
|---|---|---|---|
| Search suggestions panel | `search-bar.component.scss` `.panel-wrapper` | `absolute` | `$z-index-super` |
| Navbar dropdown | `navbar-menu/dropdown/dropdown.component.scss` `.dropdown` | `absolute` | `$z-index-4` |
| Navbar sub-menu | `navbar-menu/dropdown/sub-menu/...scss` | `absolute` | — |
| Select options | `components/layout/select/select.component.scss` `.options` | `absolute` | `2` |
| User menu | `user-menu.component.scss` `.menu` | — | `$z-index-super` |

- **Overlay działa też w `<p-sidebar>`** (mobilne menu) — panel nakłada się na treść sidebara, kontener nic nie chowa. NIE rób wariantu in-flow (`position: static`) z chowaniem sąsiada (`[class.hidden]` na rodzeństwie) — to był jednorazowy anty-wzorzec w search-barze, **usunięty** jako niespójny ze standardem. In-flow rozważ DOPIERO gdy overlay udowodnij że się nie mieści (clipping w kontenerze) — i wtedy to świadoma decyzja, nie default.
- **z-index ze skali** `_z-index.vars.scss`: `$z-index-4` (zwykłe dropdowny) lub `$z-index-super: 9999` (panele krytyczne: search, user-menu, tooltip). NIGDY hardcoded liczba (poza istniejącym `.options: 2`).
- Brak współdzielonego `%dropdown` placeholdera / mixina — każdy panel pozycjonuje się sam (anchor `top: 100%` + `left/right`).

### Dependency Injection

- **MUSI być constructor injection**:
  ```ts
  constructor(
    private formBuilder: UntypedFormBuilder,
    private cartService: CartService,
    private messagesService: MessagesService
  ) {}
  ```
- NIGDY `inject()` — Angular 16 ma to ale projekt nie używa, dla spójności trzymaj się constructor
- NIGDY `readonly #foo` — Angular 16 nie używa # prefix syntax. Pola prywatne tylko przez `private` keyword.

### State + RxJS

- **MUSI być RxJS** — `Observable`, `BehaviorSubject`, `Subject`
- **NIGDY suffix `$` w nazwach observables / Subject fieldów / lokalnych** — to globalna konwencja, ale w monopolex `$` jest **wyłączony**. Używaj opisowych nazw: `phrase` (zamiast `phrase$`), `recentSection`, `panelVisibility`, `destroySubject` (zamiast `destroy$`).
  - Powód: ujednolicony naming z resztą zmiennych projektu, brak wizualnego szumu.
  - Jeśli musisz odróżnić observable od subjectu, użyj sufiksu `Subject` dla podmiotu (`panelVisibleSubject`) i czystej nazwy dla wystawionego observable (`panelVisibility`).
- Manual unsubscribe pattern:
  ```ts
  private subscription!: Subscription
  ngOnDestroy(): void {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }
  ```
- LUB takeUntil pattern z destroy Subject (BEZ `$`):
  ```ts
  private destroySubject = new Subject<void>()
  ngOnDestroy(): void {
    this.destroySubject.next()
    this.destroySubject.complete()
  }
  ```
- NIGDY signals (`signal()`, `computed()`, `effect()`) — Angular 16 ich nie ma w stable

### Forms

- `UntypedFormBuilder`, `UntypedFormGroup` — projekt używa Untyped
- `Validators.required` etc. z `@angular/forms`

### Templates (HTML)

- **MUSI być `*ngIf` / `*ngFor` / `*ngSwitch`** — Angular 16 nie wspiera nowej składni
- `[ngClass]="{ ... }"` dla warunkowych klas
- `*ngIf="foo as bar"` dla destructuring
- Layout: `<ng-container *ngIf>` dla wrapper bez DOM
- Self-closing dla mat-icon: `<mat-icon ...></mat-icon>` (NIE samozamykające — Angular 16 templates ich nie obsługują w pełni)

### Skeleton — stany ładowania danych (`appSkeleton` + `<app-layout-skeleton>`)

**To JEST standard ładowania treści w projekcie.** Dla ładowania danych (listy, karty, sekcje, strony) NIE pisz własnych spinnerów/kropek — użyj systemu skeleton. Migoczący „shimmer" w kształcie realnej treści.

**Trzy części (nie myl ich):**
1. **`[appSkeleton]`** — dyrektywa z `SharedModule`. Znaczasz nią element TREŚCI, którego „pudełko" ma się zamienić w migoczący blok. Ustawia tylko `data-skeleton="true"` — **sama nic nie rysuje**.
2. **`<app-layout-skeleton [inProgress]="loading">`** — komponent z `LayoutSkeletonModule`. Gdy `inProgress`: mierzy wszystkie `[data-skeleton]` w środku (ResizeObserver + `SkeletonHelper`), chowa realne elementy (`opacity: 0`), nakłada animowane `.skeleton-block` (shimmer) w ich miejscach, ustawia `pointer-events: none`. **Bez tego wrappera `appSkeleton` nie robi NIC.** **Każdy oznaczony element = JEDEN blok shimmer** — chcesz kilka pasków → kilka `appSkeleton` elementów; wystarczy jeden blok na obszar → JEDEN element `appSkeleton` (NIE powielaj `<div appSkeleton>` ×N dla jednego bloku — to szum).
3. **`SkeletonHelper`** — provider w `core.module` (root). Mierzy pozycje/rozmiary. Nie wołasz go ręcznie.

**Kanoniczny wzorzec — JEDEN template treści renderowany dwa razy** (raz z dummy w skeletonie, raz z realnymi danymi). Skeleton pokazuje REALNY KSZTAŁT treści (dummy dane), nie osobny placeholder:
```html
<ng-container *ngIf="inProgress; else dataTpl">
  <app-layout-skeleton [inProgress]="inProgress">
    <ng-container *ngTemplateOutlet="contentTpl; context: { data: SKELETON_X_DATA, inProgress: true }" />
  </app-layout-skeleton>
</ng-container>
<ng-template #dataTpl>
  <ng-container *ngTemplateOutlet="contentTpl; context: { data: data, inProgress: false }" />
</ng-template>
<ng-template #contentTpl let-data="data" let-inProgress="inProgress">
  <!-- realny markup; elementy do shimmera oznaczone appSkeleton -->
  <app-product-hint appSkeleton [inProgress]="inProgress" [data]="data" />
</ng-template>
```

**Dummy dane:** `…/configuration/skeleton-data.ts`, eksport `SKELETON_<ENTITY>_DATA` (`SKELETON_PRODUCT_DATA`, `SKELETON_CATEGORY_DATA`). Wspólne stałe: `@components/layout/skeleton/configuration/skeleton-placeholders.ts` (`TEXT_SHORT/MEDIUM/LONG`, `DEFAULT_PRICE`, `DEFAULT_IMG`). (Niespójność w repo: home ma `SKELETON_DATA_HOME` — nowe pisz `SKELETON_<ENTITY>_DATA`.)

**`[inProgress]` propaguje W DÓŁ:** komponenty renderowane w skeletonie biorą `@Input() inProgress` i chowają interaktywne części (`*ngIf="!inProgress"`, `[showWishlistButton]="!inProgress"`). Przekaż `inProgress` przez całą gałąź renderowaną w skeletonie.

**Klasy pomocnicze** (toggled `="inProgress"`) — korekty layoutu pod pomiar bloków: `[class.skeleton-container]`, `[class.skeleton-summary]` (np. zdejmij `position: sticky` żeby bloki trafiły w statyczny flow), `[class.skeleton]` (np. `min-height` żeby zarezerwować miejsce zanim zmierzy).

**Wtórne ładowanie** (dane JUŻ są, doczytujesz przy paginacji/filtrze): NIE skeleton, tylko `<app-layout-loading-overlay [display]="inProgress" />` + ewentualnie `[class.greyed-out]` (global, `opacity: 0.7`). Skeleton = TYLKO initial load (gdy treści jeszcze nie ma).

**Moduły:** `appSkeleton` → moduł musi importować `SharedModule`. `<app-layout-skeleton>` → importuj `LayoutSkeletonModule`. `SkeletonHelper` w root.

**Testy:** `MockDirective(SkeletonDirective)` w `declarations`, `MockModule(LayoutSkeletonModule)` w `imports`. Obecność: `spectator.queryAll(SkeletonDirective)` (asercja na liczbę). Toggle klas: `expect(el).toHaveClass('skeleton-container')` przy `inProgress`, `not.toHaveClass` gdy `false`. NIE testuj shimmera/pomiaru — to wewnętrzne `LayoutSkeletonComponent`.

### Testy

- **Karma + Jasmine** + Spectator + ng-mocks
- Asercje:
  - `expect(x).toBeTrue()` / `toBeFalse()` (NIE `toBe(true)`)
  - `expect(spy).toHaveBeenCalledOnceWith(arg)` / `toHaveBeenCalled()` / `not.toHaveBeenCalled()`
  - `jasmine.createSpy()`, `jasmine.createSpy().and.returnValue(...)`
- Spies reset: `spy.calls.reset()` (NIE `mockReset()`)
- Mock data: dedykowane shared directory `src/test/data/` (NIE per-component dummy.ts ani inline w spec)
  - **Lokalizacja**: `src/test/data/<mirror-of-app-path>/fake-data.ts` (lub `fake-data-<purpose>.ts` gdy >1 plik na komponent)
  - **Alias importu**: `@test/data/...`
  - **Eksport**: nazwane `dummy<PascalName>` (`dummyNavbarMenuItemData`, `dummySuggestions`, `dummyCategoryHint`)
  - **Path mirror nie jest 1:1** — `header-bottom-bar` w app dzieli się na `header/bottom-bar/` w test/data
  - **Przykład**: spec w `src/app/ecommerce/components/header-bottom-bar/search-bar/suggestions-panel/items/category-hint-item/category-hint-item.component.spec.ts` → dummy w `src/test/data/ecommerce/components/header/bottom-bar/search-bar/suggestions-panel/items/category-hint-item/fake-data.ts`
- Wzorzec test:
  ```ts
  const createComponent = createComponentFactory({
    component: CartCouponsFormComponent,
    imports: [ButtonModule, ReactiveFormsModule, MockModule(MatIconModule)],
    providers: [
      MockProvider(CartService, { addCoupon: jasmine.createSpy() }),
    ],
  })
  ```

### Imports / Path aliases

Z `tsconfig.json`:
- `@app/*` → `src/app/*`
- `@components/*` → `src/app/components/*`
- `@core/*` → `src/app/core/*`
- `@shared/*` → `src/app/shared/*`
- `@ecommerce/*` → `src/app/ecommerce/*`
- `@authentication/*` → `src/app/authentication/*`
- `@env/*` → `src/environments/*`
- `@prov/*` → `src/providers/*`
- `@assets/*` → `src/assets/*`
- `@data/*` → `src/data/*`
- `@test/*` → `src/test/*`
- `@mock/*` → `src/mock/*`

ESLint blokuje WSZYSTKIE relative imports (`patterns: [".*"]`) — to nie negocjacja.

### SCSS

- Stylelint: `sass-guidelines` + `idiomatic-order`
- Max nesting: 5, max compound selectors: 6
- **MUSI używać $ variables**: `$space-1..6`, `$color-bright`, `$color-info`, `$color-success`, `$color-danger`, `$color-dark-secondary`, `$font-size-xs/base`, `$border-radius-very-small`, etc.
- **MUSI używać @include mixins**: `@include md { ... }` (responsive), `@include absolute-height(80px)`, etc.
- **MUSI używać @extend placeholders**: `@extend %stretch-horizontally`
- Partials w `src/assets/scss/partials/` — `_layout.vars.scss`, `_layout.mixins.scss`, etc.
- `@import 'src/assets/scss/partials/layout.mixins'` — używamy `@import` (sass-guidelines), NIE `@use`
- `:ng-deep` jest dozwolone (override stylelint)

### i18n

- `$localize\`tekst\`` w TS, atrybut `i18n` w HTML
- Locale: en (default), pl
- xliffmerge dla extraction

### Ikony

- **mat-icon** używa `[fontIcon]="..."`:
  ```html
  <mat-icon [fontIcon]="'arrow_drop_down'" data-testid="toggle-icon" />
  ```
- **PrimeIcons** tylko w `<p-button>` przez `icon` input:
  ```html
  <p-button icon="pi pi-arrow-left" class="back-button button-inverted" />
  ```
- Material Icons fonts: `material-icons` + `material-symbols` ładowane z `node_modules` (zob. `angular.json` styles)
- Ikona jako tekst gradientowy (rzadkie): w SCSS przez `linear-gradient` + `background-clip: text` (jak `.label::before` w `coupons-form.component.scss`)

### PrimeNG buttons — host class

p-button w `monopolex-frontend` stylowany WYŁĄCZNIE klasą na hoście. Definicje w `src/assets/scss/partials/overrides/primeng/_button.overrides.scss`. **NIGDY** `[outlined]` / `[text]` / `[severity]`.

Dostępne warianty:

| Klasa | Wygląd | Kiedy |
|---|---|---|
| (brak) | Brand gradient — pełny CTA | PRIMARY akcja |
| `.button-inverted` | Outlined: białe tło, primary border + text | SECONDARY CTA |
| `.button-inverted-gradient` | Gradient-border outlined, na hover wypełnia gradientem | PRIMARY w dialogach / formularzach |
| `.button-no-border` | Bez ramki, białe tło, label w gradient | Link-style ("Go back") |
| `.button-transparent` | Tło transparentne | Akcja na ciemnym/kolorowym tle |
| `.button-grey` | Neutralne szare tło | Drugorzędne akcje |
| `.button-success` | Zielone tło | Confirm / approve |
| `.button-white` | Białe tło z outline | Akcje na ciemnym tle |
| `.back-button` | Sztywne 36px wysokości, zwykle z `icon="pi pi-arrow-left"` | "Wróć" (zwykle łączone z `.button-inverted`) |

Łączenie: można `class="back-button button-inverted"`. Lokalna klasa komponentu PIERWSZA (`class="more-button button-inverted"`).

---

## Dostępne zmienne SCSS (frontend)

Zanim wymyślisz wartość — sprawdź czy istnieje zmienna. Pełne źródło: `src/assets/scss/partials/vars/_*.vars.scss`.

### Spacing — numeryczna skala (`$space-X`)

`$space-05: 1px`, `$space-1: 4px`, `$space-2: 8px`, `$space-3: 16px`, `$space-4: 24px`, `$space-5: 32px`, `$space-6: 48px`, `$space-7: 64px`, `$space-8: 80px`, `$space-9: 96px`, `$space-10: 112px`, `$space-11: 128px`, `$space-12: 144px`, `$space-13: 160px`

### Font sizes — t-shirt scale

`$font-size-3xs: 8px`, `$font-size-2xs: 10px`, `$font-size-xss: 11px`, `$font-size-xs: 12px`, `$font-size-sm: 14px`, `$font-size-base: 16px`, `$font-size-lg: 18px`, `$font-size-xl: 20px`, `$font-size-2xl: 24px`, `$font-size-3xl..10xl` (28..128px). Plus `$font-big-size-base..2xl` (240..288px) dla hero.

### Font weights — descriptive (NIE numbers)

`$font-weight-very-small: 200`, `-small: 300`, `-normal: 400`, `-light-bold: 500`, `-bold: 600`, `-very-bold: 700`, `-super-bold: 800`

### Font families

`$font-family-primary: 'Open Sans'`, `$font-family-secondary: 'Inter'`, `$font-family-icon: 'icon-foxic'`

### Colors

- Primary/secondary/tertiary: CSS custom properties (`#{var(--color-primary)}`) → wartość ustawiana w runtime z `:root`
- Static palette: `$color-bright`, `$color-bright-secondary/tertiary/quinmary`, `$color-dark`, `$color-dark-secondary/tertiary/quinmary` (uwaga: "quinmary" — projektowa pisownia, NIE poprawiaj na "quinary")
- Status: `$color-success`, `$color-success-light/secondary`, `$color-danger`, `$color-danger-light`, `$color-warning`, `$color-info`, `$color-info-light`

### Breakpoints

`$sm: 576px`, `$md: 768px`, `$lg: 992px`, `$xl: 1300px`, `$xxl: 1700px`. Używane przez mixin `@include md { ... }` etc. (zob. `_layout.mixins.scss`).

### Import partials

```scss
@import 'src/assets/scss/partials/layout.mixins';
@import 'src/assets/scss/partials/layout.vars';
```

Bez `_` prefix, bez `.scss` suffix (sass-guidelines convention). Ścieżka od repo root.

---

## NEVER (auto-blokuje pre-edit hook)

- `@if`, `@for`, `@switch` w `.html` — Angular 16 ich nie wspiera, używaj `*ngIf`/`*ngFor`/`*ngSwitch`
- `inject(SomeService)` w komponencie/serwisie — używaj constructor injection
- `signal()`, `computed()`, `effect()`, `input()`, `output()` — używaj RxJS / @Input / @Output
- `standalone: true` w Componencie — wszystko musi być w NgModule
- `readonly #foo` (private hash syntax) — używaj `private foo` keyword
- `null` w kodzie aplikacyjnym — używaj `undefined` (eslint blokuje przez no-null)
- Relative import (`from '../../foo'`) — eslint blokuje
- `TestBed.createComponent` — używaj Spectator
- `mockReturnValue` (Jest) w specach — Karma używa `jasmine.createSpy().and.returnValue(...)`
- `toBe(true)` / `toBe(false)` w asercjach — używaj `toBeTrue()` / `toBeFalse()`
- Suffix `$` w nazwach observables / Subjectów / lokalnych zmiennych — w monopolex zakaz, używaj opisowych nazw (`phrase`, `recentSection`, `panelVisibility`, `destroySubject`)

---

## Komendy uruchomieniowe

- Install: `yarn install`
- Start (en): `yarn start`
- Start (pl): `yarn start:pl`
- Test: `yarn test` (lub `yarn test:chrome`)
- Test + coverage: `yarn test:code-coverage`
- Lint: `yarn lint`
- Build prod: `yarn build:prod`
- e2e Cypress: `yarn cypress:open` / `yarn cypress:run`
- SSR dev: `yarn dev:ssr`
- i18n extract: `yarn i18n:extract`

---

## NIE MIGRUJ

To jest projekt utrzymaniowy. NIE proponuj migracji do:
- standalone components
- signals
- new control flow
- `inject()` 
- Jest

Bez wyraźnej prośby. Jeśli widzisz okazję do uproszczenia w obecnym stylu (np. wycięcie martwego kodu, uporządkowanie helpersa) — zaproponuj, ale nie zmieniaj architektury.
