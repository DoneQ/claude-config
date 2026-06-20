# monopolex-online-platform-suite — mapa projektu

> Żywy dokument. Aktualizuj gdy poznasz nowe rejony kodu lub gdy struktura się zmieni.

## Co to jest

Wieloskrzynkowa aplikacja webowa (Single Page App) — portal klienta MONOPOLEX. Nx monorepo, Angular 18, signal-first, layer-strict, ENT-grade auth (MSAL Azure).

## Top-level layout

```
apps/app/                    # główna aplikacja SPA (jedyna na ten moment)
libs/app/<domain>/<layer>/   # cała logika domenowa, podzielona na warstwy
plugins/app/<layer>/         # @netland/* — infrastruktura (utils, ui, models, data-access)
docs/STYLEGUIDE.md           # autorytatywny styleguide
tools/                       # workspace tools
```

## Domeny i ich warstwy

Każda domena ma SUBSET tych warstw (zwykle 5-7 z poniższych):

| Layer | Cel | Co tu siedzi |
|---|---|---|
| `models/` | Interfejsy, enumy, DTO | `interface Address`, `enum AddressType`, `AddressDto` |
| `utils/` | Pure functions | helpers, walidatory, pipes, transformers |
| `ui/` | Dumb/presentational | `app-address-card`, `app-address-form` (komponenty bez DI poza Angular core) |
| `ui-pipes/` | Globalne pipes | rzadko per-domena, częściej w `@netland/ui-pipes` |
| `data-access/` | Stan + I/O | `AddressFacadeService`, `AddressDataService`, `AddressMapper`, `provideFakeHandlers([...])` |
| `feature-<name>/` | Smart components | 1 feature = 1 component + jego dzieci. Container, używa Facade. |
| `routes/` | Routing config | lazy-loaded route definitions per domain |
| `ref-*` | Re-export API | publiczna powierzchnia domeny dla innych domen |
| `api-all` | Cross-domain ref | dla `auth/api-all` — bramka dla domain consumentów |

### Lista domen (sprawdź `tsconfig.base.json` paths dla aktualnej listy)

`address`, `auth`, `device`, `example`, `order`, `portal`, `service-requests`, `shared`, `wishlist`

`example` to wzorcowa domena — jeśli nie wiesz jak coś zrobić, sprawdź jak jest w `example`.

## Punkty wejścia

- **Bootstrap**: `apps/app/src/main.ts` — bootstrap standalone application
- **Router root**: szukaj w `apps/app/src/app/` (zwykle `app.routes.ts` lub równoważne)
- **Auth init**: MSAL configuration + interceptors w `auth/data-access`
- **Theme + globals**: `apps/app/src/assets/scss/styles.scss` + partials w `apps/app/src/assets/scss/partials/`
- **Overrides PrimeNG/Material**: `apps/app/src/assets/scss/partials/overrides/`

## Kluczowe abstrakcje

### `LoadingState<T>` (z `@netland/data-access`)

```ts
interface LoadingState<T> {
  isLoading: boolean
  data?: T
  error?: string
}
```

Każdy slot stanu w XState używa tego typu. `createInitialState(isLoading?)` to factory.

### Facade pattern

```ts
@Injectable({ providedIn: 'root' })
export class XFacadeService {
  readonly #state = signal<XState>(initialXState)
  readonly listState = computed(() => this.#state().list)
  readonly detailsState = computed(() => this.#state().details)

  readonly #dataService = inject(XDataService)
  readonly #mapper = inject(XMapper)

  loadX(id: string): Observable<void> {
    this.#state.update(s => ({ ...s, details: createInitialState(true) }))
    return this.#dataService.getOne$(id).pipe(
      tap(response => {
        const data = this.#mapper.toModel(response.data)
        this.#state.update(s => ({ ...s, details: { isLoading: false, data, error: undefined } }))
      }),
      map(() => void 0),
    )
  }
}
```

### Mappers — DTO ↔ Model

```ts
@Injectable({ providedIn: 'root' })
export class XMapper {
  toModel(dto: XDto): X { ... }
  toDto(model: XCreate): XCreateDto { ... }
}
```

### Fake Backend (non-prod)

`provideFakeHandlers([...])` w `xDataAccessConfig(env)` — w non-prod zwraca fake responses, w prod realne providers. Pozwala demo / dev bez backendu.

### Auth permission directive

```html
<button *mopsAuthHasPermission="'Examples.Create'">...</button>
```

Structural directive — używa `effect()` na sygnale permission z `AUTH_CONTEXT` injection token.

## Typowe gotchas

1. **Layer naming jest STRICT**. Jeśli importujesz z `@mops/example/feature-list` w `data-access/`, ESLint błędnie pozwoli (bo to ten sam domain), ale to złamie clean architecture. Pomyśl czy to ma sens.

2. **Cross-domain musisz iść przez `auth/api-all` lub `shared` lub `netland`**. Inne domeny zablokuje enforce-module-boundaries.

3. **Mappery są injectowane** — nie używaj static `XMapper.toModel()`, tylko `inject(XMapper).toModel(dto)`.

4. **`computed()` jest pure** — nie wywołuj efektów ubocznych. Side effects = `effect()` z DestroyRef.

5. **`input.required()`** rzuci jeśli rodzic nie poda wartości. Używaj `input<T>(default)` jeśli wartość jest opcjonalna.

6. **Test data — osobny dummy.ts**. `libs/app/<dom>/<layer>/tests/<comp>/<comp>.dummy.ts`. NIE inline w specach.

## Komendy które używam najczęściej

```bash
pnpm install                    # po pull
pnpm lint:app                   # linting
pnpm unit-test:app              # testy app
nx test <project>               # testy konkretnego project
nx graph                        # interactive dependency graph
nx affected:test                # testy tylko zmienionych libs
nx generate @nx/angular:library --name=<n> --directory=app/<d>/<l>
```

## Aktualizacja tej mapy

Gdy poznasz nowy obszar (nowa domena, nowa abstrakcja, nieoczywisty pattern), DOPISZ tu krótki akapit z linkiem do reprezentatywnego pliku. Mapa rozrasta się od dna a nie od góry.
