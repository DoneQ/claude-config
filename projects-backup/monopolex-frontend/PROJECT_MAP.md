# monopolex-frontend — mapa projektu

> Żywy dokument. Aktualizuj gdy poznasz nowe rejony kodu lub gdy struktura się zmieni.

## Co to jest

Sklep e-commerce MONOPOLEX, frontend. Klasyczna aplikacja Angular 16 z SSR, NgModules, RxJS-first state management, PrimeNG. Projekt utrzymaniowy — NIE migrujemy do nowszych patternów bez wyraźnej decyzji.

## Top-level layout

```
src/
├── app/
│   ├── app.module.ts                     # root NgModule
│   ├── app-routing.module.ts             # główny routing
│   ├── components/<domain>/<feature>/    # komponenty zorganizowane domenowo
│   ├── core/                             # SINGLETONS — services, guards, helpers, interceptors, repositories
│   ├── ecommerce/                        # główna feature obszar (z własnym routingiem)
│   ├── pages/                            # strony błędu / not found
│   └── shared/                           # współdzielone komponenty, dyrektywy, pipes, animations
├── assets/
│   ├── images/
│   └── scss/                             # globalny SCSS, partials
│       ├── partials/                     # _layout.vars.scss, _layout.mixins.scss, etc.
│       └── styles.scss
├── data/                                 # statyczne dane (consts, msg dictionaries)
├── environments/                         # env.ts, env.prod.ts
├── locale/                               # XLF tłumaczenia (en, pl)
├── mock/                                 # mocki dla dev
├── providers/                            # providers.ts — DI providers (env-specific)
├── test/                                 # shared test data, helpers
├── main.ts                               # browser bootstrap
├── main.server.ts                        # SSR bootstrap
└── styles.scss                           # entry — importuje assets/scss/styles
```

## `app/components/` — struktura domenowa

```
components/
├── address/      auth/      basic/     blog/
├── cart/         category/  checkout/  cms/
├── layout/       manufacturer/         marketing/
├── product/      tag/       user/
```

Każdy `<feature>/` zawiera podkatalogi per komponent (`coupons-form/`, `summary/`, etc.):
```
coupons-form/
├── coupons-form.component.ts
├── coupons-form.component.html
├── coupons-form.component.scss
├── coupons-form.component.spec.ts
└── coupons-form.module.ts          # ZAWSZE — deklaruje + eksportuje
```

## `app/core/` — singletony

| Folder | Co tu siedzi |
|---|---|
| `api/` | Interfejsy odpowiedzi API, base classes |
| `authentication/` | Auth module, MSAL integracja |
| `breadcrumbs/` | Breadcrumb service + types |
| `configs/`, `configurations/` | Enumy, constants, type configs |
| `entities/` | Modele domenowe (`Cart`, `Product`, `Coupon`, `Message`, etc.) |
| `errors/` | Error handlers, types |
| `guards/` | Router guards |
| `helpers/` | `ApiHelper`, `PriceHelper`, etc. |
| `interceptors/` | HTTP interceptors |
| `mocks/` | Service mocks |
| `pipes/` | Globalne pipes |
| `repositories/` | HTTP repositories — `CartRepository`, `ProductRepository` |
| `services/<domain>/` | Logika biznesowa — `CartService`, `ProductService`, etc. |
| `validators/` | Custom Angular validators |

`core/services/service.ts` — bazowa klasa `Service` z `validateAndReturnData()` używana wszędzie.

## Path aliases (z `tsconfig.json`)

```
@app/*           → src/app/*
@components/*    → src/app/components/*
@core/*          → src/app/core/*
@shared/*        → src/app/shared/*
@ecommerce/*     → src/app/ecommerce/*
@authentication/* → src/app/authentication/*
@env/*           → src/environments/*
@prov/*          → src/providers/*
@assets/*        → src/assets/*
@images/*        → src/assets/images/*
@data/*          → src/data/*
@test/*          → src/test/*
@mock/*          → src/mock/*
crypto           → node_modules/crypto-js
```

ESLint blokuje wszystko z `..` — używaj aliasów.

## Punkty wejścia

- **Browser**: `src/main.ts`
- **SSR**: `src/main.server.ts`, `server.ts` (Express)
- **Root module**: `src/app/app.module.ts`
- **Routing**: `src/app/app-routing.module.ts`, `src/app/ecommerce/ecommerce-routing.module.ts`
- **Theme**: `src/styles.scss` → `src/assets/scss/styles.scss`
- **i18n**: `src/locale/messages.pl.xlf`, generowane przez `yarn i18n:extract`

## Kluczowe abstrakcje

### `Service` (core/services/service.ts)

```ts
@Injectable()
export class Service {
  constructor(private apiHelper: ApiHelper) {}

  validateAndReturnData<TData>(
    request: Observable<ApiResponse<TData>>,
    appType: AppType
  ): Observable<TData | undefined> { ... }
}
```

Bazowa klasa do wrapowania HTTP requests + error handling przez `ApiHelper`.

### Repository pattern

`core/repositories/<domain>/<domain>.repository.ts` — czysty HTTP, używa `HttpClient`. Konsumowane przez Service w warstwie wyżej.

### Service per domain

`core/services/<domain>/<domain>.service.ts` — logika biznesowa, transformacje, side effects (cache, logging). NIGDY w komponencie HTTP bezpośrednio.

### LiveObject + LocalStorage cache

`core/services/cache/local-storage/live-object/<domain>/<domain>.service.ts` — cache w localStorage z `requiresUpdate()` checkiem.

### MessagesService

`core/services/messages/messages.service.ts` — globalna szyna komunikatów (success/error/info). `newMessage` to Observable.

## Typowe gotchas

1. **Każdy komponent MUSI mieć osobny module** (`<comp>.module.ts`). To jest wymóg projektu nawet jeśli Angular 16 wspiera `standalone`.

2. **Untyped Forms** — `UntypedFormBuilder`, `UntypedFormGroup`. Projekt nie migrował do typed forms.

3. **`null` jest zabronione** — eslint `no-null` reguła. Używaj `undefined`.

4. **Relative imports zabronione** — eslint `no-restricted-imports patterns: [".*"]`.

5. **Karma syntax**: `toBeTrue()` / `toBeFalse()` zamiast `toBe(true/false)`. `jasmine.createSpy()` + `.and.returnValue(...)`. `spy.calls.reset()`.

6. **SCSS — sass-guidelines**: max-nesting 5, max-compound 6, używaj `@import` (NIE `@use`), zmienne globalne dostępne automatycznie.

7. **SSR**: niektóre operacje (window, document, localStorage) wymagają `isPlatformBrowser` check. Sprawdź `core/services/server-side-response/`.

8. **`p-button` styling** — przez host class (`button-grey`, `button-transparent`, etc.), NIE przez `[outlined]`/`[text]`.

## Komendy

```bash
yarn install
yarn start              # ng serve --configuration en
yarn start:pl
yarn test               # Karma
yarn test:chrome
yarn test:code-coverage
yarn lint
yarn build:prod
yarn cypress:open
yarn cypress:run
yarn dev:ssr            # SSR dev server
yarn i18n:extract       # XLF extraction
```

## Aktualizacja tej mapy

Gdy poznasz nowy obszar (nowy serwis, repo, helper), DOPISZ tu krótki akapit. Wartość tego pliku rośnie z czasem.
