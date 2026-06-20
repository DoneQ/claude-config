# monopolex-online-platform-suite — reguły projektowe

> **Profil**: MODERN. Angular 18 + standalone + signals. To jest preferowany styl dla nowego kodu.
>
> **Stack**: Nx 19 monorepo, pnpm, Jest, Spectator + ng-mocks, Playwright, PrimeNG 17, Angular Material 18, MSAL Azure auth.

Reguły poniżej są **NADRZĘDNE** wobec globalnych w `~/.claude/rules/`. W razie konfliktu — wygrywa ten plik.

---

## Pre-flight checklist — WYPISZ przed każdą edycją kodu

Przed dotknięciem pliku w tym projekcie wypisuję w czacie krótką listę:

```
[ ] Standalone component (standalone: true)?
[ ] inject() z readonly #foo lub readonly bar?
[ ] @if/@for/@switch — nigdy *ngIf/*ngFor?
[ ] Signal/computed/input.required dla state?
[ ] data-testid na każdym interaktywnym elemencie?
[ ] Path alias @mops/* lub @netland/* (nigdy ../..)?
[ ] Layer warstwy nie łamią enforce-module-boundaries?
[ ] (jeśli komponent z dummy) <comp>.dummy.ts w tests/?
```

Jeśli nie wiem odpowiedzi → czytam istniejący kod w sąsiednim folderze ZANIM piszę.

---

## TWARDE WYMAGANIA (MUST)

### Komponenty

- **MUSI być standalone** — `@Component({ standalone: true, imports: [...] })`. NIGDY NgModule do deklarowania komponentów (poza root + lazy routes).
- **ChangeDetectionStrategy.OnPush** dla każdego nowego komponentu, chyba że istnieje konkretna przyczyna inaczej (i opisz ją w 1-linijkowym komentarzu)
- Selector prefix: `mops-` (lub `netland-` w `plugins/app/`)

### Dependency Injection

- **MUSI być `inject()`**. NIGDY constructor injection.
- Private/internal: `readonly #foo = inject(Foo)` — `#` prefix
- Protected/public: `readonly bar = inject(Bar)` — bez prefixu
- Wszystkie inject CALLS grupowane razem, po inputach/outputach, przed properties

### State

- **MUSI być signals** (`signal`, `computed`, `effect`) dla wewnętrznego stanu komponentu / serwisu
- **MUSI być `input.required<T>()` / `input<T>()`** zamiast `@Input()`
- **MUSI być `output<T>()`** zamiast `@Output() ev = new EventEmitter()`
- RxJS dozwolone tylko gdzie naturalne (HTTP requests, async streams) — preferuj signals dla state

### Facade + Mappers + LoadingState

- Każda domena (`@mops/<domain>/data-access`) ma:
  - `XFacadeService` — eksponuje signals (`computed()`) i metody (`loadX$()`, `createX$()`, etc.)
  - `XDataService` — czysty HTTP, zwraca `Observable<ApiResponse<XDto>>`
  - `XMapper` — `toModel(dto): X` / `toDto(model): XCreate` — DTO ↔ Model konwersja
  - `XState` interface oparty o `LoadingState<T> = { isLoading: boolean, data?: T, error?: string }`
- Komponent **NIGDY** nie woła DataService bezpośrednio — tylko Facade
- Komponent **NIGDY** nie wywołuje Mappera — to robi Facade

### Templates (HTML)

- **MUSI być `@if` / `@for` / `@switch`** — nowa składnia control flow. NIGDY `*ngIf` / `*ngFor` / `*ngSwitch`.
- `@for` MUSI mieć `track` (zwykle `track item.id`)
- Self-closing tags dla void elements i komponentów bez content: `<input />`, `<mops-spinner />`, `<netland-icon />`
- Czytanie sygnału w warunku z `as`:
  ```html
  @if (state(); as data) {
    <div>{{ data.name }}</div>
  }
  ```
- Kolejność klas: lokalne component classes → globalne (`class="more-button button-outline"`)

### Atrybuty HTML — sortowanie

Prettier-plugin-organize-attributes wymusza kolejność:
1. `*ngIf` / structural directives
2. zwykłe atrybuty (`class`, `id`, `type`)
3. inputy `[foo]`
4. two-way `[(foo)]`
5. outputy `(foo)`
6. `data-testid`

Pisząc HTML pisz w tej kolejności od razu — formatter to wymusi i tak.

### Testy

- **Jest** + Spectator + ng-mocks
- Folder testów: `libs/app/<dom>/<layer>/tests/<name>/`
- Mockowanie HTTP: `dataService.getOne$.mockReturnValue(of({ code: 200, data: dummyDto }))` — Jest mocks, NIE jasmine
- **Mock data** (sibling file pattern):
  - **Lokalizacja**: `<name>.dummy.ts` w tym samym katalogu co `<name>.spec.ts` (NIE per-component test/data mirror jak monopolex-frontend; NIE inline w spec)
  - **Eksport**: nazwane `dummy<PascalName>`
  - **Przykład**: `storage.service.spec.ts` + `storage.service.dummy.ts` w tym samym folderze `tests/storage/`

### Layer dependencies (enforce-module-boundaries)

NIGDY nie importuj z layeru wyżej w hierarchii:
- `models` → tylko `models`
- `utils` → `utils`, `models`
- `data-access` → `data-access`, `utils`, `ref`, `models`, `ui-pipes`
- `ui` → `ui`, `ui-pipes`, `utils`, `models`, `feature`
- `feature` → `feature`, `ui`, `data-access`, `utils`, `ref`, `models`
- `routes` → `feature`, `data-access`, `utils`, `ref`, `models`
- Cross-domain: tylko przez `auth/api-all`, `shared`, `netland`

### Order of class members

```
1. input/output signals (required → optional → outputs)
2. inject() calls
3. properties (public → protected → private)
4. methods (public → protected → private)
```

### Linki / ścieżki routingu — inline, BEZ agregatora

Ścieżki tras i linki nawigacyjne trzymamy **inline jako string-literały w miejscu użycia** — to świadomy standard projektu (niezależność feature-modułów). Tak jest w całym kodzie, tak zostaw:

- Route defs: `path: 'details/:id'`, `path: 'invoices'`
- `this.#router.navigate(['addresses', 'invoices', 'details', id])`
- `routerLink="/addresses/invoices"` / element sidebar: `routerLink: '/addresses/invoices'`

**NIGDY nie twórz centralnego registry/agregatora ścieżek** (`*_PATH` / `*_LINK` const, route-path enum, link builder). Jeśli kusi „DRY na ścieżkach" — STOP, to NIE jest standard tego projektu. Linki encji z backendu pozostają data-driven przez model `Link` (`item.link.url`) — to inny przypadek, nie dotyczy ścieżek strukturalnych.

`ResourceKey` enum (wartości `'addresses'`, `'invoices'`, …) to klucze fake-backendu — pokrywają się ze ścieżkami przypadkiem, **NIE używaj go do routingu**.

### SCSS

- Stylelint: `standard-scss` + `idiomatic-order`
- Variables w `apps/app/src/assets/scss/partials/vars/_*.vars.scss` — używaj ich
- Overrides PrimeNG/Material w `apps/app/src/assets/scss/partials/overrides/` — **NIGDY w komponencie**
- `:host { ... }` dla styli komponentu jako całości
- **Import partials z PEŁNĄ ścieżką od workspace root**:
  ```scss
  @import 'apps/app/src/assets/scss/partials/_layout.vars.scss';
  @import 'apps/app/src/assets/scss/partials/mixins/_breakpoint.mixins.scss';
  ```
  Z leading `_` i `.scss` extension (vs frontend bez nich).
- **`example/` to szkielet mocno niedoszlifowany — NIE używaj jako wzorca**. Tam są raw hex, raw rem, brak zmiennych — sprzeczne ze STYLEGUIDE. Real wzorce stylów są w `address/`, `device/`, `order/`. Jeśli sięgam do `example/` w ogóle (np. po strukturę katalogów), KRZYŻOWO weryfikuję każdy szczegół z real domain zanim go zaadaptuję.

### Ikony

- **mat-icon**: `[fontIcon]="..."` (Angular Material icons)
- **PrimeIcons**: `<p-button icon="pi pi-..." />`
- Konwencja jak w angular.md global

---

## Dostępne zmienne SCSS (mops)

Zanim wymyślisz wartość — sprawdź czy istnieje zmienna w `apps/app/src/assets/scss/partials/vars/`.

### Spacing — descriptive scale (`$spacing-*`)

`$spacing-very-small: 4px`, `$spacing-small: 8px`, `$spacing-default: 16px`, `$spacing-large: 24px`, `$spacing-very-large: 32px`, `$spacing-section: 40px`

### Padding — `$padding-*`

`$padding-small`, `$padding-default`, `$padding-medium` (wartości w `_padding.vars.scss`)

### Font sizes — descriptive

`$font-size-small`, `$font-size-default`, `$font-weight-default` (zob. `_font.vars.scss`)

### Border

`$border-radius-small`, `$border-width-default` (zob. `_border.vars.scss`)

### Colors

- Brand: `$color-primary: #0077B6`, `$color-primary-light: #0492E8`, `$color-primary-gradient` (linear-gradient)
- Secondary: `$color-secondary: #112A46`, `$color-secondary-light: #023E8A`
- Bright: `$color-bright: #fff`, `$color-bright-secondary/tertiary`, `$color-brith-quinmary` (uwaga: literówka "brith" w projekcie — NIE poprawiaj, tak jest w bazie)
- Dark: `$color-dark`, `$color-dark-secondary/tertiary/quinmary` (też z "quinmary")
- Status: `$color-success` (#19A95F), `$color-success-light/secondary`, `$color-danger` (#DB2130), `$color-danger-light`, `$color-warning`, `$color-warning-secondary`, `$color-info-light`
- `$color-transparent: transparent`

### Breakpoints

`$sm: 576px`, `$md: 768px`, `$lg: 992px`, `$xl: 1200px` (uwaga: różni się od frontend gdzie xl=1300px), `$xxl: 1700px`

### Mixins

`@include md { ... }` (responsive), `@include text-gradient($color-primary-gradient)` (gradient text), `@include absolute-height(80px)` itp. — zob. `_layout.mixins.scss`, `mixins/_breakpoint.mixins.scss`, `mixins/_dimmension.mixins.scss`, `mixins/_gradient.mixins.scss`

### Placeholders

`%stretch-horizontally` itp. — `@extend %stretch-horizontally` (zob. `_layout.placeholders.scss`)

---

## NEVER (auto-blokuje pre-edit hook)

- `*ngIf`, `*ngFor`, `*ngSwitch` w `.html` — używaj `@if`/`@for`/`@switch`
- `constructor(private foo: Foo)` w komponencie/serwisie — używaj `readonly #foo = inject(Foo)`
- `@Input()` decorator — używaj `input()` / `input.required()`
- `@Output() ... = new EventEmitter()` — używaj `output<T>()`
- `standalone: false` — wszystko ma być standalone
- `null` — używaj `undefined`
- Relative import `from '../../...'` — używaj `@mops/...` lub `@netland/...`
- `TestBed.createComponent(...)` — używaj Spectator
- `private foo` w klasie (TS keyword) — używaj `#foo` syntax
- Bezpośredni `console.log` — używaj `LogService` lub `debug` flagi w env

---

## Path aliases (z tsconfig.base.json)

- `@mops/<domain>` lub `@mops/<domain>/<layer>` (np. `@mops/example/data-access`)
- `@netland/<layer>` (np. `@netland/utils`, `@netland/ui-pipes`) — infrastruktura
- Domains: `address`, `auth`, `device`, `example`, `order`, `portal`, `service-requests`, `shared`, `wishlist`
- Layers: `models`, `utils`, `ui`, `ui-pipes`, `data-access`, `feature-<name>`, `routes`, `ref-*`

---

## Komendy uruchomieniowe

- Install: `pnpm install`
- Lint: `pnpm lint:app` (lub `nx lint app`)
- Test: `pnpm unit-test:app` (lub `nx test <project>`)
- Build: `nx build app`
- Graf zależności: `nx graph`

Vault docs: `docs/STYLEGUIDE.md` w repo.
