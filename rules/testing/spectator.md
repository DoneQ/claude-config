# Angular Testing — Spectator + ng-mocks

## Framework

- **ZAWSZE Spectator + ng-mocks**. NIGDY surowy TestBed.
  - `createComponentFactory({ component, imports: [...], providers: [MockProvider(...)] })`
  - `createServiceFactory({ service, mocks: [...] })`
  - `MockModule(SomeModule)`, `MockProvider(SomeService, { method: jasmine.createSpy() })`, `MockProviders(...)` (bulk no-op stubs), `MockDeclarations(ChildA, ChildB)`, `MockDirective(...)`

## Selektory w testach

**Dozwolone formy** (od najczęstszej):

1. **`spectator.query(byTestId('X'))`** — zwraca `Element` (z classList, attributes). Najczęstsza. Wymaga `data-testid="X"` na elemencie.
2. **`spectator.queryAll(byTestId('X'))`** — wszystkie elementy z tym testid (dla `*ngFor` listy gdzie każdy item ma tę samą klasę testid).
3. **`spectator.query(Component)`** — gdy potrzebujesz INSTANCJI komponentu (dostęp do `@Input` props, `@Output` emiterów). NIE wymaga testid.
4. **`spectator.queryAll(Component)`** — wszystkie instancje komponentu (np. items w `*ngFor`). NIE wymaga testid. Działa identycznie jak `query(Component)` ale zwraca tablicę.
5. **`spectator.query('[data-testid="X"]', { read: Directive })`** — gdy potrzebujesz instancji DYREKTYWY na elemencie (np. Button, MatIcon). Selektor atrybutowy `[data-testid="X"]` jest OK; tag selektor (`p-button`) — NIE.
6. **`spectator.query<HTMLAnchorElement>(byTestId('item'))`** — typed cast bo trzeba dostępu do specyficznych pól (np. `href`).

**Zakazane**:

- `spectator.query('p-button')` / `spectator.query('app-foo')` — CSS tag selektor bez testid. Brak stabilności — testid jest jedyną stabilną osią między HTML a testem.
- `spectator.query('.class')` / `spectator.query('#id')` — CSS klasa/ID. Klasy zmieniają się przy refactorze stylów, ID nie powinny być w komponentach.
- `nativeElement.querySelector(All)` — DOM API bypassujące byTestId discipline.
- `spectator.query(Component, { read: ElementRef })` — kombo które nie jest używane w projekcie. Zamiast tego dodaj `data-testid` na komponent host i użyj `byTestId(X)` (zwraca element bezpośrednio).

**Reguła zakupu testid**: jeśli twój test musi sprawdzić KLASĘ CSS / atrybut / DOM property elementu — element MUSI mieć `data-testid`. Dla `*ngFor` listy ten sam testid na każdym item element (`spectator.queryAll(byTestId('item'))` zwróci tablicę).

**Hook blokuje**: tag selektory (`spectator.query('p-button')`), CSS klasy/ID (`spectator.query('.X')`), `querySelector(All)`. Pozwala na `[data-testid="X"]` z read.

## Scope deklaracji zmiennych — najwęższy WYMAGANY poziom

**Twarda reguła**: każda zmienna testu (`let service`, `let router`, `let subject`, lokalne `const`) i jej `spectator.inject(...)` / przypisanie żyją na **najwęższym `describe`/`it`, który ją faktycznie używa**. NIE deklaruj globalnie „bo wygodnie". Zasięg zmiennej = mapa tego, gdzie jest używana — szeroki zasięg kłamie, że zmienna jest wspólna dla całego suite.

| Gdzie zmienna jest używana | Gdzie ją zadeklarować |
|---|---|
| W całym suite (np. `spectator`) | top `describe` + top `beforeEach` |
| W kilku `it` jednego `describe` | `let` na poziomie TEGO `describe` + lokalny `beforeEach` z `spectator.inject(...)` |
| W jednym `it` | `const x = spectator.inject(...)` w body tego `it` |
| W zagnieżdżonym `describe` w `describe` | na poziomie zagnieżdżonego, NIE rodzica — jeśli rodzic jej nie używa |

**`MockProvider(...)` / providers w factory ZOSTAJĄ globalnie** — to deklaracja DI (komponent wstrzykuje serwis przy każdym `createComponent`), NIE zmienna testowa. Globalny jest **provider**, lokalny jest **uchwyt do spy** (`SpyObject`).

**Carve-out — zmienne ZASILAJĄCE factory też zostają globalnie.** Dyskryminator NIE brzmi „gdzie jest użyta w `it`", tylko: **czy to setup/wiring providera (→ top), czy czysty uchwyt do asercji (→ zawęź)?** `Subject`/`BehaviorSubject` wpięte w `MockProvider({ events: subject.asObservable() })`, albo wartość mutowana by sterować komponentem (`mockWindow.innerWidth`) — **MUSZĄ być top-level**, nawet jeśli `subject.next(...)` wołasz tylko w jednym `describe`. Bez nich `createComponent` w globalnym `beforeEach` rzuci (observable === undefined) i KAŻDY test umrze. Zawężaj WYŁĄCZNIE `spectator.inject(...)`-owe uchwyty `SpyObject` używane czysto do asercji.

```ts
describe('FooComponent', () => {
  let spectator: Spectator<FooComponent>
  let routerEvents: Subject<NavigationEnd>   // ← ZASILA MockProvider → top, mimo że .next() tylko w 'navigation'

  const createComponent = createComponentFactory({ component: FooComponent })

  beforeEach(() => {
    routerEvents = new Subject<NavigationEnd>()
    spectator = createComponent({
      providers: [MockProvider(Router, { events: routerEvents.asObservable() })],
    })
  })

  describe('navigation', () => {
    it('should react on NavigationEnd', () => {
      const router = spectator.inject(Router)   // ← czysty uchwyt asercji → lokalnie
      routerEvents.next(new NavigationEnd(1, '/x', '/x'))
      expect(router.navigateByUrl).toHaveBeenCalled()
    })
  })
})
```

❌ ŹLE — `router` użyty w jednym `it`, ale `let` + inject globalnie:
```ts
describe('FooComponent', () => {
  let spectator: Spectator<FooComponent>
  let router: SpyObject<Router>          // ← użyty tylko w 'navigation'

  beforeEach(() => {
    spectator = createComponent()
    router = spectator.inject(Router)    // ← inject dla wszystkich, choć 1 test go chce
  })

  describe('navigation', () => {
    it('should navigate on click', () => {
      expect(router.navigateByUrl).toHaveBeenCalledOnceWith(href)
    })
  })
})
```

✅ DOBRZE — uchwyt w najwęższym scope, provider zostaje w factory:
```ts
describe('FooComponent', () => {
  let spectator: Spectator<FooComponent>

  const createComponent = createComponentFactory({
    component: FooComponent,
    providers: [MockProvider(Router)],   // ← provider globalny (DI), OK
  })

  beforeEach(() => {
    spectator = createComponent()
  })

  describe('link resolution', () => {
    let productService: SpyObject<ProductService>   // ← 2 testy w tym describe

    beforeEach(() => {
      productService = spectator.inject(ProductService)
    })

    it('should resolve link', () => { ... })
    it('should recompute on change', () => { ... })
  })

  describe('navigation', () => {
    it('should navigate on click', () => {
      const router = spectator.inject(Router)       // ← 1 test → const w it
      ...
    })
  })
})
```

**Why**: globalny `let` + inject akumuluje setup, którego większość testów nie potrzebuje, i sugeruje fałszywie „ten spy jest osią całego suite". Wąski scope = czytelnik widzi przy `describe('navigation')` dokładnie te zależności, które ta grupa testuje. Spójne z regułą `expectedXxx` (niżej) — deklaracja idzie tam, gdzie jest konsumowana.

## Konwencja testów

- Pierwszy test komponentu: `it('should create', () => expect(spectator.component).toBeTruthy())`
- Każdy `it` zaczyna się od `should ...`
- **Słowa NOT / NO piszemy WIELKIMI literami**: `it('should NOT show error when...')`, `it('should contain NO items initially')`
- **Arrange → Act → Assert (AAA)** — sekcje oddzielone PUSTĄ LINIĄ, **BEZ komentarzy `// Arrange` / `// Act` / `// Assert`**. Wyjątek: plik EDYTOWANY już je ma → dodawaj dla spójności.
  ```ts
  it('should toggle visibility on flatLayout change', () => {
    const items = spectator.queryAll(byTestId('phrase-item'))

    items.forEach((item) =>
      expect(item.classList.contains('layout-flat')).toBeFalse()
    )

    spectator.setInput('flatLayout', true)

    items.forEach((item) =>
      expect(item.classList.contains('layout-flat')).toBeTrue()
    )
  })
  ```
- **Gdy test ma >2 cykle Act → Assert** — zastanów się czy nie podzielić na osobne `it`. Powtarzanie w jednym `it` jest OK gdy weryfikuje TRANSITION (przed/po). 3+ stany = test robi za dużo.
- **Pokrewne asercje grupuj w jednym `it`** z wieloma `expect`-ami — nie rozbijaj sztucznie. Np. jeden `it('should get correct overviewData for each status')` exercising every enum value zamiast 5 osobnych `it`.
- **Child components w dedykowanych sekcjach** (TWARDA reguła):
  ```ts
  describe('should contain child components', () => {
    // 1 test per komponent → płaskie it z nazwą komponentu
    it('SidebarLanguage', () => {
      expect(spectator.query(SidebarLanguageComponent)).toBeTruthy()
    })

    // >1 test per komponent → describe(NazwaKomponentu) z osobnymi it dla each aspect
    describe('PrimeNG Button', () => {
      it('should be present', () => {
        const button = spectator.query(Button)
        expect(button).toBeTruthy()
      })

      it('should receive search-button-flat class from flatLayout', () => {
        const buttonEl = spectator.query(byTestId('submit-button'))
        expect(buttonEl!.classList.contains('search-button-flat')).toBeFalse()
        spectator.setInput('flatLayout', true)
        expect(buttonEl!.classList.contains('search-button-flat')).toBeTrue()
      })
    })

    describe('SuggestionsPanel', () => {
      it('should be present', () => { ... })
      it('should receive flatLayout from parent', () => { ... })
      it('should emit phraseSelected on user click', () => { ... })
    })
  })

  describe('should NOT contain child components', () => {
    it('SuggestionsPanel when panelVisible is false', () => {
      expect(spectator.query(SearchSuggestionsPanelComponent)).toBeFalsy()
    })
  })
  ```

  - **W "should contain child components" idą WSZYSTKIE asercje o child component**: jego obecność, propagacja `@Input`, klasa CSS aplikowana przez parent, `@Output` interakcje.
  - **W "should NOT contain child components" idą testy że dziecko ZNIKA** (np. po `*ngIf` warunku).
  - **Grupowanie**: 1 test per komponent → `it('NazwaKomponentu')`. **2+ testy per komponent → `describe('NazwaKomponentu')** z `it('should be present')`, `it('should receive X from parent')`, etc. każdy aspect to osobny `it`.
  - Tytuł `it` w grouped describe zaczyna od `should` (jak default), bez powtarzania nazwy komponentu (bo describe już to mówi).
- Test skeleton dla komponentów z responsive logic:
  ```ts
  describe('base', () => { ... })          // wspólna logika
  describe('standard view', () => { ... }) // desktop
  describe('mobile view', () => { ... })   // mobile
  ```

## Kluczowe wzorce Spectator

### `isX()` predicate pattern

Gdy test sprawdza predicate `isX(obj): boolean` na wielu wariantach — shared testObject + assertion w `afterEach`. Każdy `it` body tylko mutuje testObject:

```ts
describe('should return false', () => {
  let testObject: Foo

  beforeEach(() => {
    testObject = { ...validFoo }
  })

  afterEach(() => expect(isFooValid(testObject)).toBeFalse())

  it('when name is empty', () => { testObject.name = '' })
  it('when age is negative', () => { testObject.age = -1 })
  it('when email missing @', () => { testObject.email = 'noat' })
})
```

### Server / browser branching (SSR)

Top-level `describe('when on server')` z PLATFORM_ID override:

```ts
describe('when on server', () => {
  const createComponent = createComponentFactory({
    component: Foo,
    providers: [{ provide: PLATFORM_ID, useValue: 'server' }],
  })
  // tylko serwer-specific testy (np. że innerHTML nie renderuje)
})
```

### Subjects dla route params / observables

```ts
let paramsSubject: Subject<Params>
beforeEach(() => {
  paramsSubject = new Subject<Params>()
  activatedRouteSpy.params = paramsSubject.asObservable()
})

it('should react to param change', () => {
  paramsSubject.next({ id: '42' })
  expect(spectator.component.id).toBe('42')
})
```

### `fakeAsync` + `tick()` + `detectChanges()` dla promise-driven state

```ts
it('should update after promise resolves', fakeAsync(() => {
  spectator.component.load()
  tick()
  spectator.detectChanges()
  expect(spectator.query(byTestId('result'))).toBeTruthy()
}))
```

### Subscription lifecycle

Sprawdź `closed` przed i po destroy:

```ts
expect(spectator.component['subscriptionRoute'].closed).toBeFalse()
spectator.component.ngOnDestroy()
expect(spectator.component['subscriptionRoute'].closed).toBeTrue()
```

### Cleanup destroy w spec

```ts
afterEach(() => spectator.component.ngOnDestroy())
```

## Spy capture (NIGDY leading-semicolon)

- NIE pisz `;(spy as jasmine.Spy).and.returnValue(...)` — wymusza semicolon prefix bo prettier wyrzuca `;` z poprzedniej linii
- Capture w zmienną:
  ```ts
  const fetchSpy = service.fetch as jasmine.Spy
  fetchSpy.and.returnValue(of(data))
  ```

## Mocki w specach — discipline (TWARDE)

Wszystkie mocki MUSZĄ być **deklarowane w `createComponentFactory` / `createServiceFactory`**, NIE w body testu, NIE w `beforeEach` (poza resetem stanu).

**Child components / modules / pipes / directives** — w `declarations` / `imports` factory:
```ts
const createComponent = createComponentFactory({
  component: ParentComponent,
  declarations: [
    MockComponent(ChildAComponent),
    MockComponent(ChildBComponent),
    MockComponents(ChildCComponent, ChildDComponent),  // bulk
    MockPipe(PriceToGrossStringPipe, (value) => `gross:${value?.gross}`),
    MockDirective(RedirectDirective),
  ],
  imports: [
    MockModule(FormsModule),
    MockModule(MatIconModule),
  ],
  providers: [
    MockProvider(SomeService, { method: spy }),
    MockProviders(NoOpServiceA, NoOpServiceB),  // bulk no-op
  ],
})
```

**Spies — wzorzec C (DEFAULT, dla service-klas)**: `MockProvider(Service)` bez configu w factory, w `beforeEach` pobierasz przez `spectator.inject` jako `SpyObject<Service>`. autoSpy('jasmine') tworzy spy z każdej metody automatycznie.

```ts
describe('FooComponent', () => {
  let spectator: Spectator<FooComponent>
  let categoryService: SpyObject<CategoryService>
  let authService: SpyObject<AuthService>

  const createComponent = createComponentFactory({
    component: FooComponent,
    providers: [
      MockProvider(CategoryService),
      MockProvider(AuthService),
    ],
  })

  beforeEach(() => {
    spectator = createComponent({ props: { item: dummyItem } })
    categoryService = spectator.inject(CategoryService)
    categoryService.getLink.and.returnValue(dummyLink)
    authService = spectator.inject(AuthService)
  })

  it('should call categoryService.getLink', () => {
    spectator.component.doSomething()

    expect(categoryService.getLink).toHaveBeenCalledOnceWith(...)
  })
})
```

**Spies — wzorzec D (ALTERNATYWA, gdy default returnValue dla całego suite)**: `MockProvider(Service, { method: jasmine.createSpy().and.returnValue(dummyValue) })` — inline w factory. Stosuj gdy wszystkie testy chcą tego samego defaultu. Override per-test przez `spectator.inject(Service).method.and.returnValue(other)`.

```ts
providers: [
  MockProvider(CategoryService, { getLink: jasmine.createSpy().and.returnValue(dummyLink) }),
],
```

**Wzorzec D OBOWIĄZKOWY dla properties których autoSpy NIE OBSŁUŻY** — observables, BehaviorSubject, plain values, gettery. autoSpy robi spy z metod (functions), NIE z observable properties.

```ts
providers: [
  MockProvider(SearchSuggestionsService, { suggestions: EMPTY }),  // observable property
  MockProvider(TOKEN_VISIBILITY, {
    show: new BehaviorSubject<boolean>(false).asObservable(),  // observable property
    setVisibility: jasmine.createSpy(),                         // metoda — można też pominąć (autoSpy)
  }),
],
```

### `.calls.reset()` — kiedy konieczny

- **Wzorzec C**: NIE wymaga resetu — autoSpy tworzy nowe spies per `createComponent()`.
- **Wzorzec D**: WYMAGA resetu w `beforeEach`. Spy jest singleton — calls akumulują. Reset po `spectator = createComponent()`, PRZED dalszą logiką.

```ts
// Wzorzec D wymaga resetu:
providers: [
  MockProvider(TOKEN_X, { setVisibility: jasmine.createSpy() }),
  MockProvider(CategoryService, {
    getLink: jasmine.createSpy().and.returnValue(dummyLink),
  }),
]

beforeEach(() => {
  spectator = createComponent()
  sidebarVisibility = spectator.inject(TOKEN_X)
  sidebarVisibility.setVisibility.calls.reset()  // wymagane
  categoryService = spectator.inject(CategoryService)
  categoryService.getLink.calls.reset()  // wymagane jeśli metoda wywoływana w testach z toHaveBeenCalledOnceWith
})
```

**Jeśli wzorzec D + metoda wywoływana podczas `createComponent` (np. w `ngOnChanges`)**: reset w beforeEach wymaże ten initial call. Wtedy:
- Asercja "should set X from method return value" — NIE używaj `toHaveBeenCalledOnceWith` (zliczanie nie zadziała po resecie). Użyj `toHaveBeenCalledWith` (sprawdza args, ignoruje liczbę) lub asercjonuj na **stanie komponentu** (`expect(spectator.component.link).toEqual(dummyLink)`).
- Lokalny reset w teście dla "should recompute on change" — najpierw reset, potem trigger zmiany, potem `toHaveBeenCalledOnceWith` na nowych args.

### Wzorzec D OBOWIĄZKOWY (autoSpy ZAWODZI)

- **InjectionToken** (`MockProvider(TOKEN_X, { method: jasmine.createSpy() })`) — `MockProvider(TOKEN_X)` BEZ configu zwraca null/undefined. autoSpy nie obsługuje InjectionToken.
- **Metoda wywoływana w inicjalizacji** (`ngOnInit`, `ngOnChanges`, konstruktor), której **return value jest potrzebny do renderu** (np. `[href]="link.href"` gdzie `link = service.getLink(...)`). autoSpy zwraca `undefined` zanim `.and.returnValue()` w `beforeEach` zdąży się ustawić — komponent crashuje. Wzorzec D z inline default zapewnia wartość OD MOMENTU utworzenia mocka.
- **Observable / BehaviorSubject / property** (nie metoda) — `MockProvider(X, { suggestions: EMPTY, store$: new BehaviorSubject(initial) })`. autoSpy robi spy tylko z funkcji, NIE z observable properties. Bez explicit config, property = undefined.

**Wzorzec C działa** dla service-klas których metody są wywoływane WYŁĄCZNIE w handlerach (event handlers, lifecycle hooks PO `createComponent` wraca, async callbacks). Wtedy `.and.returnValue(...)` w beforeEach zdąży ustawić zwrot zanim test wywoła metodę.

### Anti-pattern — top-level `const` spy poza `describe` (ZAKAZANE)

```ts
// ŹLE:
const getLinkSpy = jasmine.createSpy().and.returnValue(dummyLink)
const setVisibilitySpy = jasmine.createSpy()

describe('FooComponent', () => {
  const createComponent = createComponentFactory({
    providers: [MockProvider(CategoryService, { getLink: getLinkSpy })],
  })
  beforeEach(() => { getLinkSpy.calls.reset() })
})
```

Spy singleton akumuluje calls, wymusza ręczny reset. Ukrywa zależność — patrząc na `getLinkSpy` nie widać że to mock CategoryService. Wzorzec C/D załatwia 100% przypadków bez tej duplikacji.

### Dostęp do mocka w teście

TYLKO przez `spectator.inject(Service)` jako `SpyObject<Service>`, NIGDY przez private fields:
```ts
// TAK (wzorzec C/D):
const service = spectator.inject(CategoryService)
expect(service.getLink).toHaveBeenCalledOnceWith(id, name, friendlyUrl)

// TAK gdy pobierasz na chwilę bez przypisania do `let`:
expect(spectator.inject(CategoryService).getLink).toHaveBeenCalledOnceWith(...)

// NIE — sięganie do private field przez nawiasy:
const getLinkSpy = spectator.component['categoryService'].getLink as jasmine.Spy
```

**Typing**: deklaruj `let service: SpyObject<ServiceClass>` na poziomie `describe` (po `let spectator`). `SpyObject<T>` daje typing każdej metody jako `jasmine.Spy & T['method']` — nie trzeba `as jasmine.Spy` cast.

**Generic `spectator.inject<T>(T)` cast NIE jest potrzebny** — Spectator zwraca już `SpyObject<Service>`. W istniejącym kodzie z `inject<T>(T)` — zostaw dla spójności, w nowym nie pisz.

### Don'ts (mocki)

- NIGDY top-level `const X = jasmine.createSpy()` poza `describe` (anti-pattern wyżej)
- NIGDY `spectator.component['privateField']` — wszystkie zależności przez DI, dostęp przez `spectator.inject`
- NIGDY definicja `jasmine.createSpy()` inline w body testu / w `beforeEach` (poza spy event'a tymczasowego per test, np. `const event = new MouseEvent(...); spyOn(event, 'preventDefault')`)
- NIGDY mock przez `spyOn(spectator.component, 'method')` — testowanie własnej implementacji zamiast publicznego API
- NIGDY `.calls.reset()` w globalnym `beforeEach` dla autoSpy — nowy spectator = nowy spy, reset zbędny

## `$localize` — NIE testuj wywołań

**Twarda reguła**: NIGDY nie asercjonuj na `mockLocalize` (`expect(mockLocalize).toHaveBeenCalledWith([...], [])`). Asercja na `mockLocalize` to string snapshot — refactor copy psuje testy bez powodu. Test pyta o ZNAK, nie o ZACHOWANIE.

**Co WOLNO testować zamiast tego**:
- **Warunkową obecność elementu** przez `byTestId`: `expect(spectator.query(byTestId('sublabel'))).toBeTruthy()` — testuje TWOJĄ logikę (kiedy element jest renderowany).
- **`textContent` TYLKO gdy mapping key → text jest DYNAMICZNY** (np. `getLabel(status: Status)` zwraca różne `$localize` per enum value). Wtedy asercja sprawdza mapping logikę, nie konkretny string. Rzadkie — w 90% przypadków testowanie textContent też jest snapshotem.

**Co ZAKAZANE**:
- `expect(mockLocalize).toHaveBeenCalledWith([...], [])` w jakiejkolwiek formie
- `it('should translate X')` / `it('should localize X')` — taki tytuł ZAWSZE sygnalizuje snapshot literalu, nie testowanie zachowania
- `mockLocalize.calls.reset()` w `beforeEach` gdy w pliku NIE MA już żadnej asercji na `mockLocalize` — reset bez assertion to martwy kod, usuwaj razem

## Triggering — przez UI/output, NIE przez `spectator.component.method()`

**Twarda reguła**: w testach komponentów akcję wywołujesz przez **interakcję na DOM lub `@Output` emisję child komponentu**, NIE przez bezpośrednie wywołanie metody komponentu — nawet jeśli metoda jest `public`.

**Mapping triggerów**:

| Akcja użytkownika | Jak triggerować w teście |
|---|---|
| Click button/anchor | `spectator.click(byTestId('submit-button'))` |
| Enter w inputcie | `spectator.keyboard.pressEnter(byTestId('input'))` |
| Inny key (Esc, Tab, arrow) | `spectator.dispatchKeyboardEvent(byTestId('input'), 'keydown', 'Escape')` |
| Input change / typing | `spectator.typeInElement('text', byTestId('input'))` lub `spectator.dispatchFakeEvent(byTestId('input'), 'input')` z pre-set `.value` |
| Focus / blur | `spectator.dispatchFakeEvent(byTestId('input'), 'focus')` / `'blur'` |
| `@Output` z child komponentu | `spectator.query(ChildComponent)!.outputName.emit(payload)` |
| `@Input` zmiana | `spectator.setInput('inputName', value)` |
| `HostListener('document:X')` | `spectator.dispatchFakeEvent(document, 'X')` lub `window.dispatchEvent(new XEvent(...))` |
| `HostListener('document:keydown.escape')` | `document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }))` |

**Why**: test przez UI weryfikuje template binding `(click)="..."` — bez triggera UI ten kontrakt jest niesprawdzony. `@Output` emit weryfikuje że `(outputName)="parentHandler($event)"` jest podpięty w HTML.

**Przykład — ŹLE**:
```ts
it('should navigate with provided phrase', () => {
  spectator.component.onSearchAllRequested('laptop')

  expect(router.navigate).toHaveBeenCalledOnceWith([...], { queryParams: { searchPhrase: 'laptop' } })
})
```
Test przechodzi gdy `onSearchAllRequested` istnieje, ale nie sprawdza CZY child komponent emit-uje przez właściwy output i CZY parent ma handler podpięty w HTML.

**Przykład — DOBRZE**:
```ts
it('should navigate with provided phrase from suggestions panel', () => {
  spectator.component.panelVisible = true
  spectator.detectChanges()
  const panel = spectator.query(SearchSuggestionsPanelComponent)!

  panel.searchAllRequested.emit('laptop')

  expect(router.navigate).toHaveBeenCalledOnceWith([...], { queryParams: { searchPhrase: 'laptop' } })
})
```

**Wyjątki — kiedy WOLNO `spectator.component.method()`**:
- **Lifecycle hooks**: `spectator.component.ngOnDestroy()`, `ngOnInit()` — to nie są user-facing akcje, weryfikujesz lifecycle. OK.
- **Setter inputu który nie ma trigger UI w komponencie** (np. boolean flag ustawiany przez parent property binding): `spectator.setInput('panelVisible', true)`. Jeśli komponent nie ma `@Input() panelVisible`, ale ma `panelVisible: boolean` jako public state ustawiany w środku — wtedy musisz manipulować state przez assignment `spectator.component.panelVisible = true` (jako helper SETUP, nie jako trigger testowanego zachowania). Asercja działa na DOM/output, nie na `panelVisible` value.
- **Nie ma DOM/output trigger** (rzadkie, prawie nigdy w komponentach UI). Np. metoda wywoływana TYLKO przez parent przez `ViewChild.method()`. Wtedy `spectator.component.method()` reprezentuje "parent wywołał" — to jest jego kontrakt.

**Don'ts**:
- `spectator.component.onClick()` gdy istnieje przycisk z `(click)="onClick()"` — użyj `spectator.click`
- `spectator.component.onPhraseSelected(item)` gdy child emit-uje `(phraseSelected)="onPhraseSelected($event)"` — użyj `panel.phraseSelected.emit(item)`
- `spectator.component.search()` gdy istnieje submit-button lub Enter handler — użyj `spectator.click` lub `pressEnter`
- `spectator.component.onPhraseChange(value)` gdy istnieje `(ngModelChange)="onPhraseChange($event)"` lub `(input)="..."` na inputcie — typing w input lub `spectator.dispatchFakeEvent`

## Magic values w testach — ZAKAZ, używaj `expectedXxx` / dummy directly

**Twarda reguła**: NIGDY nie pisz magic literali (stringów, liczb) DUPLIKOWANYCH w teście. Każda wartość użyta w `expect(...)` musi mieć JEDNO źródło prawdy w teście:

1. **Wartość jest BEZPOŚREDNIO polem dummy** → użyj `dummyHint.name` directly w `expect`, **NIE twórz** `expectedXxx`. Tworzenie zmiennej `const expectedName = dummyHint.name` to **niepotrzebny indirection** — czytelnik patrzy "co tu jest expected" i widzi `dummyHint.name`, wie od razu skąd wartość.
2. **Wartość arbitralna do testu** (nie pochodzi z dummy, np. typing input) → zadeklaruj **semantyczną stałą** (`const phrase = 'foo'`, `const newId = 99`) — ta sama wartość jest też INPUTEM triggera, więc nie nazywaj jej `expectedXxx`, tylko semantycznie. Reuży w triggerze + asercji.
3. **Wartość DERYWOWANA z dummy** (konkatenacja, hardcoded struktura wiedząc o dummy, złożony obiekt) → zadeklaruj `const expectedXxx = ...` w spec'u (NIE w fake-data, NIE inline jeśli używane wielokrotnie).

**Kluczowa różnica `dummy.field` vs `expectedXxx`**:
- `expect(x).toEqual(dummyHint.name)` ← bezpośrednie pole, BEZ `expectedName`. Wartość ma JEDNO źródło prawdy: dummy. Indirection nic nie wnosi.
- `expect(x).toEqual(expectedBreadcrumb)` gdzie `expectedBreadcrumb = ` `` `${dummyParent.name} / ${dummyChild.name}` `` ← KONSTRUKCJA z wielu pól dummy. `expectedXxx` ma sens bo budujesz coś nowego, ten coś zasługuje na nazwę.

### `expectedXxx` vs `dummyXxx` — gdzie to żyje

**Twarda reguła nazewnictwa + lokalizacji**:

| Rodzaj | Nazwa | Gdzie |
|---|---|---|
| **Dummy** — INPUT do testu (API response, props, state setupu) | `dummyXxx` | Plik fake-data (osobny od spec'a, per projekt convention) |
| **Expected** — wartość porównywana w `expect(...).toEqual(...)` | `expectedXxx` | Plik **spec'a**, w najwęższym scope w którym jest używana |

**Why**: expected w spec = blisko asercji, czytelnik nie musi otwierać drugiego pliku. Eksportowanie expected z fake-data zaciera linię między "co system DOSTAJE" (dummy) a "co system MA ZWRÓCIĆ" (expected).

**Scope deklaracji expected w specu** (od najwęższego do najszerszego):

1. **Użyte w jednym `it`** → zadeklaruj w body tego `it`, blisko asercji:
```ts
it('should set link from CategoryService return value', () => {
  spectator.setInput('item', dummyCategoryHint)

  const expectedLinkArgs = [dummyCategoryHint.id, dummyCategoryHint.name, dummyCategoryHint.friendlyUrl] as const
  expect(categoryService.getLink).toHaveBeenCalledWith(...expectedLinkArgs)
})
```

2. **Użyte w kilku `it` jednego `describe`** → zadeklaruj na poziomie tego `describe`:
```ts
describe('searchAllRequested output', () => {
  const expectedSearchPhrase = 'laptop'

  it('should navigate with emitted phrase', () => { ... })
  it('should close panel after emit', () => { ... })
})
```

3. **Użyte w kilku `describe`'ach jednego pliku spec'a** → zadeklaruj na poziomie najwyższego (głównego) `describe`. **NIGDY na top-level pliku spec'a** (poza describe) i **NIGDY w fake-data**.

```ts
describe('SearchSuggestionsCategoryHintItemComponent', () => {
  let spectator: Spectator<...>
  const expectedBreadcrumb =
    `${dummyCategoryParentTopLevel.name} / ${dummyCategoryParentSubLevel.name}`

  describe('breadcrumb resolution', () => {
    it('should join parent names sorted by index', () => {
      ...
      expect(spectator.component.breadcrumb).toEqual(expectedBreadcrumb)
    })
  })

  describe('rendering', () => {
    it('should render breadcrumb when parents are present', () => {
      ...
      expect(breadcrumb!.textContent).toContain(expectedBreadcrumb)
    })
  })
})
```

```ts
// ŹLE — magic literal duplikowane:
spectator.typeInElement('foo', byTestId('input'))
expect(spectator.component.searchPhrase).toEqual('foo')

// DOBRZE — jedno źródło prawdy:
const phrase = 'foo'
spectator.typeInElement(phrase, byTestId('input'))
expect(spectator.component.searchPhrase).toEqual(phrase)
```

```ts
// ŹLE — magic literal hardcoded w teście:
spectator.setInput('item', dummyCategoryHintWithParents)
expect(spectator.component.breadcrumb).toEqual('Electronics / Computers')

// ŹLE — logika w expected (sort/map/join "odtwarza" komponent — to test dla testu):
const expectedBreadcrumb = dummyCategoryHintWithParents.parents!
  .slice()
  .sort((a, b) => a.index - b.index)
  .map((p) => p.name)
  .join(' / ')

// ŹLE — expected wyeksportowane z fake-data (to NIE jest dummy input, to expected output):
// fake-data.ts:
//   export const dummyCategoryHintParentsBreadcrumb = `${...}` // ← należy do specu, nie fake-data

// DOBRZE — semantyczne dummy parents w fake-data + plain expected w spec'u:
// fake-data.ts (tylko INPUTY):
//   export const dummyCategoryParentTopLevel: CategoryParent = { id: 1, name: 'Electronics', index: 0, friendlyUrl: 'electronics' }
//   export const dummyCategoryParentSubLevel: CategoryParent = { id: 2, name: 'Computers', index: 1, friendlyUrl: 'computers' }
//   export const dummyCategoryHintWithParents: SearchCategoryHint = {
//     ...,
//     parents: [dummyCategoryParentSubLevel, dummyCategoryParentTopLevel],  // intentionally unsorted
//   }
// spec.ts:
const expectedBreadcrumb =
  `${dummyCategoryParentTopLevel.name} / ${dummyCategoryParentSubLevel.name}`
spectator.setInput('item', dummyCategoryHintWithParents)
expect(spectator.component.breadcrumb).toEqual(expectedBreadcrumb)
```

```ts
// ŹLE — magic id duplikowane:
const updated = { ...dummyHint, id: 99 }
spectator.setInput('item', updated)
expect(service.getLink).toHaveBeenCalledOnceWith(99, updated.name, updated.friendlyUrl)

// DOBRZE — jedno źródło prawdy (updated):
const updated = { ...dummyHint, id: 99 }
spectator.setInput('item', updated)
expect(service.getLink).toHaveBeenCalledOnceWith(updated.id, updated.name, updated.friendlyUrl)
```

**Why**: zmiana dummy nie wymaga update'u testów z `dummy.field`. `dummyHint.name` mówi czemu ta wartość jest, `'Laptop DELL'` nic nie mówi. Literalna wartość = ukryte sprzężenie — refactor dummy bez updateu testów → testy zielone ale weryfikują przestarzałą wartość.

**Expected musi być PLAIN i DIRECT — NIE odtwarzaj logiki komponentu w teście**:

- ZAKAZ `sort`, `map`, `filter`, `reduce`, `fold` w produkcji `expected` value. Jeśli wymagasz takiej logiki — przenieś gotowy expected do fake-data (`dummyXBreadcrumb`, `dummyXParts`, `dummyXSorted`).
- Dozwolone w teście: string interpolation z dummy fields (`` `${dummy.a} / ${dummy.b}` ``), referencja do dummy.field, prosta literałowa konstanta na początku testu (`const phrase = 'foo'`).
- Powód: logika w teście to **kolejny kod do utrzymania i debugowania**. Jeśli sort/map ma bug, test będzie zielony mimo bugu w komponencie (tautologia "test odtworzył ten sam zły algorytm"). "Nie piszemy testów dla testów" — expected to ma być MOCKUP wartości, nie kopia algorytmu.

```ts
// ŹLE — derywacja przez slice z dummy fields:
const matched = dummyPhrase.text.slice(0, dummyPhrase.highlight!.length)
const rest = dummyPhrase.text.slice(dummyPhrase.highlight!.length)
expect(parts).toEqual([
  { text: matched, bold: false },
  { text: rest, bold: true },
])

// DOBRZE — plain expected w spec'u (NIE fake-data, bo to oczekiwany OUTPUT, nie INPUT):
const expectedParts: PhrasePart[] = [
  { text: 'lap', bold: false },
  { text: 'top lenovo', bold: true },
]
expect(parts).toEqual(expectedParts)
```

**Wyjątki — kiedy magic literal jest OK**:
- **Sentinel values które nie pochodzą z dummy i są SAMO-WYJAŚNIAJĄCE** (np. `expect(spy).not.toHaveBeenCalled()` — `0` jest implicit, nie wymaga zmiennej).
- **Boolean / null** (`expect(x).toBeTrue()` / `toBeFalse()` / `toBeUndefined()`) — brak duplikacji, jasne intent.
- **Wartość użyta TYLKO RAZ w teście** (jako arg do triggera, BEZ asercji na tę samą wartość). Jeśli wartość nie jest duplikowana w teście, magic literal jest akceptowalny.

## Dummy data — NIGDY inline w spec file

**Twarda reguła**: dane testowe (dummy/fake) MUSZĄ być w osobnym pliku — nigdy nie definiuj inline w `*.spec.ts`.

**Konwencja ścieżki dummy = per projekt** — patrz `<projekt>/CLAUDE.md` PRZED napisaniem. Każdy projekt ma inne konwencje (mirror directory vs sibling file, alias importu, naming pliku).

**Naming eksportów** (zasada cross-project):
- Nazwane `dummy<Name>` w PascalCase po `dummy` (`dummyNavbarMenuItemData`, `dummySuggestions`, `dummyCategoryHint`)
- Import po nazwie, NIGDY `import dummy from ...` default export

**Hook blokuje**: inline definicje `const dummy<X>` / `let dummy<X>` w plikach `*.spec.ts`. Wynoś do shared fake-data zgodnie z konwencją projektu.

## Co WOLNO trzymać w pliku spec (NIE jest dummy)

**Expected results** (wartości oczekiwane przez asercje) — gdy NIE są tym samym co dummy input:
- Użyte w jednym `it` → zdefiniuj w body tego `it`
- Użyte w kilku `it` jednego `describe` → zdefiniuj w `beforeEach` lub na poziomie tego `describe`
- NIGDY na top-level spec'a jeśli używane tylko w jednym describe

**Setup-specific config** (lokalna konfiguracja Spectator factory) — zostaje w spec.

## Co to "dummy" vs "expected"

- **Dummy** = input data symulujący API/state (`dummySuggestions`, `dummyUser`, `dummyOrderResponse`). Mock danych zewnętrznych. → osobny plik
- **Expected** = wartość którą asercja porównuje, często **derywat** z dummy lub **konkretne literały** w teście (`expect(x).toEqual({ name: 'Test' })`). Zostaje w spec, blisko asercji.
- Jeśli expected JEST tym samym co dummy (np. spy zwraca dummyX i test sprawdza że emitowano dummyX) — używaj importu, nie duplikuj.
