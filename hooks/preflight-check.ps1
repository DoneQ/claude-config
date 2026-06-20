#Requires -Version 7
<#
.SYNOPSIS
  Claude Code PreToolUse hook — anty-wzorce dla projektów monopolex.

.DESCRIPTION
  Hook czyta JSON ze stdin (Edit/Write/MultiEdit), wykrywa do jakiego projektu
  należy edytowany plik (monopolex-frontend = LEGACY, monopolex-online-platform-suite = MODERN),
  i skanuje proponowaną zawartość pod kątem anty-wzorców z CLAUDE.md projektu.

  Jeśli znajdzie naruszenie -> zwraca JSON blokujący + exit 2.

  Filozofia: "religijne przestrzeganie" - lepiej false positive niż przepuścić wiolację.
  Anti-patterny są celowo wąskie żeby ograniczyć false positives.
#>

$ErrorActionPreference = 'Stop'

# Read stdin JSON
try {
  $rawInput = [Console]::In.ReadToEnd()
  if ([string]::IsNullOrWhiteSpace($rawInput)) {
    exit 0
  }
  $payload = $rawInput | ConvertFrom-Json
}
catch {
  # Nie blokuj jeśli JSON jest popsuty — niech narzędzia działają
  exit 0
}

# Helper: zwróć listę {file_path, content} z payloadu
function Get-EditTargets {
  param($Payload)
  $targets = @()
  $tn = $Payload.tool_name
  $ti = $Payload.tool_input

  if ($tn -in @('Edit', 'Write')) {
    $content = if ($null -ne $ti.new_string) { $ti.new_string } elseif ($null -ne $ti.content) { $ti.content } else { '' }
    $targets += [pscustomobject]@{ FilePath = $ti.file_path; Content = $content }
  }
  elseif ($tn -eq 'MultiEdit') {
    foreach ($edit in $ti.edits) {
      $targets += [pscustomobject]@{ FilePath = $ti.file_path; Content = $edit.new_string }
    }
  }
  return $targets
}

# Helper: normalizuj ścieżkę dla porównań
function Resolve-NormalizedPath {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
  return $Path.Replace('\', '/').ToLowerInvariant()
}

# Helper: wykryj projekt na podstawie ścieżki
function Get-ProjectId {
  param([string]$NormalizedPath)
  if ($NormalizedPath -match 'monopolex-online-platform-suite') { return 'suite' }
  if ($NormalizedPath -match 'monopolex-frontend') { return 'frontend' }
  return $null
}

# Helper: wykryj rozszerzenie pliku
function Get-FileKind {
  param([string]$NormalizedPath)
  if ($NormalizedPath.EndsWith('.spec.ts')) { return 'spec' }
  if ($NormalizedPath.EndsWith('.ts')) { return 'ts' }
  if ($NormalizedPath.EndsWith('.html')) { return 'html' }
  if ($NormalizedPath.EndsWith('.scss')) { return 'scss' }
  return 'other'
}

# Anty-wzorce — lista obiektów: { Pattern, Message, FileKinds (which kinds to apply on) }
$AntiPatternsSuite = @(
  # HTML — modern control flow only
  @{ Pattern = '\*ngIf\b';     Msg = 'Suite: uzyj @if zamiast *ngIf (Angular 18 control flow)';     Kinds = @('html') }
  @{ Pattern = '\*ngFor\b';    Msg = 'Suite: uzyj @for zamiast *ngFor (z track function!)';         Kinds = @('html') }
  @{ Pattern = '\*ngSwitch\b'; Msg = 'Suite: uzyj @switch zamiast *ngSwitch';                       Kinds = @('html') }

  # HTML — Angular component bez children MUSI byc self-closing
  @{ Pattern = '(?s)<(app-[\w-]+)\b[^>]*>\s*</\1>'; Msg = 'HTML: Angular component bez children MUSI byc self-closing `<app-X ... />`, nie `<app-X ...></app-X>` (zob. angular.md "self-closing tags")'; Kinds = @('html') }

  # TS — DI / signals / standalone
  @{ Pattern = 'constructor\s*\(\s*(public|private|protected|readonly)\s+\w+\s*:'; Msg = 'Suite: NIGDY constructor injection. Uzyj `readonly #foo = inject(Foo)`'; Kinds = @('ts','spec') }
  @{ Pattern = '@Input\s*\(';                                                       Msg = 'Suite: uzyj sygnalow `input()` / `input.required()` zamiast @Input()';   Kinds = @('ts') }
  @{ Pattern = '@Output\s*\(\s*\)';                                                 Msg = 'Suite: uzyj `output<T>()` zamiast @Output() + EventEmitter';            Kinds = @('ts') }
  @{ Pattern = '\bstandalone\s*:\s*false\b';                                        Msg = 'Suite: komponenty MUSZA byc standalone';                                Kinds = @('ts') }
  @{ Pattern = 'TestBed\.createComponent';                                          Msg = 'Suite: uzyj Spectator (`createComponentFactory`) zamiast TestBed';      Kinds = @('spec') }
  @{ Pattern = "from\s+['""]\.\./";                                                 Msg = 'Suite: NIE relative imports - uzyj @mops/* lub @netland/* aliases';    Kinds = @('ts','spec') }

  # SCSS — viewport units zakazane w obu projektach
  @{ Pattern = '\b\d+(?:\.\d+)?(?:vh|vw|svh|lvh|dvh|svw|lvw|dvw)\b'; Msg = 'SCSS: NIGDY viewport units (vh/vw/svh/lvh/dvh) - uzyj px/rem/% (zob. angular.md drabinka decyzji)'; Kinds = @('scss') }

  # SCSS — ::ng-deep ZAKAZ w komponentach (dozwolone tylko w partials/overrides/)
  @{ Pattern = '::ng-deep|/deep/|>>>';                              PathExclude = '/partials/overrides/'; Msg = 'SCSS: NIGDY ::ng-deep w komponencie. Uzyj global override w partials/overrides/, klasa modyfikator, lub :host.X (zob. angular.md "Nadpisywanie zewnetrznych komponentow")'; Kinds = @('scss') }

  # TS — cast hacks
  @{ Pattern = '\bas\s+unknown\s+as\b';                              Msg = 'TS: NIGDY `as unknown as X` - to maskowanie typu. Fix the type (zob. typescript.md anty-wzorce)'; Kinds = @('ts','spec') }
  @{ Pattern = '\bas\s+any\b';                                       Msg = 'TS: NIGDY `as any` - to maskowanie typu. Uzyj `unknown` + narrow (zob. typescript.md anty-wzorce)'; Kinds = @('ts','spec') }

  # Spec — query rules
  @{ Pattern = '\.querySelector(All)?\s*\(';                         Msg = 'Spec: NIGDY querySelector(All) - query po byTestId(''X'') lub spectator.query(Component) (zob. angular.md "Selektory w testach")'; Kinds = @('spec') }
  @{ Pattern = "spectator\.query(?:All)?\s*\(\s*['""](?!\[data-testid)";  Msg = 'Spec: NIE query CSS selektorem (tag/klasa/id). Uzyj byTestId(''X''), spectator.query(Component) lub spectator.query(''[data-testid=\"X\"]'', { read: Directive })'; Kinds = @('spec') }

  # Spec — inline dummy data zabronione (musi byc w shared fake-data per konwencja projektu)
  @{ Pattern = '\b(const|let)\s+dummy[A-Z]\w*\s*[:=]';                Msg = 'Spec: NIGDY inline dummy w spec - wynies do shared fake-data zgodnie z konwencja projektu (zob. <projekt>/CLAUDE.md sekcja Mock data)'; Kinds = @('spec') }
)

$AntiPatternsFrontend = @(
  # HTML — Angular 16 nie wspiera nowej skladni control flow
  @{ Pattern = '@if\s*\(';     Msg = 'Frontend (A16): @if NIE jest wspierany. Uzyj *ngIf';      Kinds = @('html') }
  @{ Pattern = '@for\s*\(';    Msg = 'Frontend (A16): @for NIE jest wspierany. Uzyj *ngFor';    Kinds = @('html') }
  @{ Pattern = '@switch\s*\(';                                                                                            Msg = 'Frontend (A16): @switch NIE jest wspierany. Uzyj *ngSwitch'; Kinds = @('html') }

  # HTML — structural directives MUSZA byc na <ng-container>, nie na normalnym tagu
  @{ Pattern = '<(?!ng-container\b)[\w-]+[^>]*?\*ng(If|For|Switch)\b'; Msg = 'HTML: *ngIf/*ngFor/*ngSwitch MUSZA byc na <ng-container>, NIE na normalnym tagu (zob. angular.md "Structural directives")'; Kinds = @('html') }

  # HTML — Angular component bez children MUSI byc self-closing (<app-X ... />), NIE <app-X ...></app-X>
  # Pattern: <app-foo ...> NASTEPNIE (whitespace) NASTEPNIE </app-foo>. Wymusza `(?s)` zeby . matchowala newline.
  @{ Pattern = '(?s)<(app-[\w-]+)\b[^>]*>\s*</\1>'; Msg = 'HTML: Angular component bez children MUSI byc self-closing `<app-X ... />`, nie `<app-X ...></app-X>` (zob. angular.md "self-closing tags"). Wyjatek: mat-icon w monopolex-frontend (projektowy zakaz).'; Kinds = @('html') }

  # TS — NIGDY signals / inject / standalone
  # negative lookbehind `(?<!spectator\.)` zeby nie lapac spectator.inject() (Spectator helper)
  @{ Pattern = '(?<!spectator\.)\binject\s*\(\s*\w+(Service|Repository|Helper|Mapper|Facade|Builder|Token|Context)\b'; Msg = 'Frontend (A16): NIE inject() - uzyj constructor injection `private foo: Foo` (lub `spectator.inject<T>(T)` w spec)'; Kinds = @('ts','spec') }
  @{ Pattern = '\bsignal\s*\(';                                                                         Msg = 'Frontend (A16): signals NIE sa dostepne. Uzyj RxJS (BehaviorSubject)';        Kinds = @('ts') }
  @{ Pattern = '\bcomputed\s*\(';                                                                       Msg = 'Frontend (A16): computed() NIE jest dostepny. Uzyj RxJS (combineLatest/map)';  Kinds = @('ts') }
  @{ Pattern = '\beffect\s*\(\s*\(\s*\)\s*=>';                                                          Msg = 'Frontend (A16): effect() NIE jest dostepny. Uzyj RxJS subscribe + ngOnDestroy'; Kinds = @('ts') }
  @{ Pattern = '\bstandalone\s*:\s*true\b';                                                             Msg = 'Frontend (A16): NIE standalone - kazdy komponent w NgModule';                Kinds = @('ts') }
  @{ Pattern = 'readonly\s+#\w+';                                                                       Msg = 'Frontend (A16): NIE # prefix - uzyj `private` keyword';                     Kinds = @('ts','spec') }
  @{ Pattern = 'TestBed\.createComponent';                                                              Msg = 'Frontend: uzyj Spectator (`createComponentFactory`) zamiast TestBed';        Kinds = @('spec') }
  @{ Pattern = '\.mockReturnValue\s*\(';                                                                Msg = 'Frontend (Karma): uzyj `jasmine.createSpy().and.returnValue(...)`, NIE Jest mockReturnValue'; Kinds = @('spec') }
  @{ Pattern = '\.toBe\s*\(\s*true\s*\)';                                                               Msg = 'Frontend (Karma): uzyj `.toBeTrue()` zamiast `.toBe(true)`';                Kinds = @('spec') }
  @{ Pattern = '\.toBe\s*\(\s*false\s*\)';                                                              Msg = 'Frontend (Karma): uzyj `.toBeFalse()` zamiast `.toBe(false)`';              Kinds = @('spec') }
  @{ Pattern = "from\s+['""]\.\./";                                                                     Msg = 'Frontend: NIE relative imports - uzyj @core/@components/@shared/@ecommerce/@app aliases'; Kinds = @('ts','spec') }

  # TS — naming: metoda nazwana od triggera (onClick/onFocus/onXSelected) zamiast od akcji.
  # `(?m)^\s*on[A-Z]` lapie deklaracje metody `onFoo(` na poczatku linii; lifecycle `ngOnInit` zaczyna sie od `ng` wiec NIE wpada.
  @{ Pattern = '(?m)^\s*on[A-Z]\w*\s*\('; Msg = 'TS naming: NIE nazywaj metod od triggera (onClick/onFocus/onProductSelected/onWindowResize). Nazwa MUSI opisywac CO metoda ROBI (navigateToProduct/openPanel/closePanel/removeRecentPhrase). Lifecycle ngOnInit/ngOnChanges/ngOnDestroy sa OK. (zob. typescript.md Naming "Metody")'; Kinds = @('ts') }

  # SCSS — viewport units zakazane w obu projektach
  @{ Pattern = '\b\d+(?:\.\d+)?(?:vh|vw|svh|lvh|dvh|svw|lvw|dvw)\b'; Msg = 'SCSS: NIGDY viewport units (vh/vw/svh/lvh/dvh) - uzyj px/rem/% (zob. angular.md drabinka decyzji)'; Kinds = @('scss') }

  # SCSS — ::ng-deep ZAKAZ w komponentach (dozwolone tylko w partials/overrides/)
  @{ Pattern = '::ng-deep|/deep/|>>>';                                                                  PathExclude = '/partials/overrides/'; Msg = 'SCSS: NIGDY ::ng-deep w komponencie. Uzyj global override w partials/overrides/, klasa modyfikator, lub :host.X (zob. angular.md "Nadpisywanie zewnetrznych komponentow")'; Kinds = @('scss') }

  # SCSS — lokalna klasa `<noun>-<modifier>` wyglada jak globalna (heurystyka: konczy sie na wizualny modifier; partials/ wykluczone)
  @{ Pattern = '\.[\w-]+-(compact|wide|narrow|large|small|grey|gray|inverted|transparent|rounded)\b'; PathExclude = '/partials/'; Msg = 'SCSS naming: lokalna klasa `<noun>-<modifier>` (np. reviews-compact, icon-large) wyglada jak GLOBALNA (jak button-grey). W komponencie daj modifier osobno (.compact/.large) ALBO opisowo `<adj>-<noun>` (compact-reviews jak total-reviews). `<noun>-<modifier>` tylko w partials/ (zob. angular.md "Lokalne vs globalne klasy")'; Kinds = @('scss') }

  # SCSS — qualifying type selector (`tag.class`) blokowany przez stylelint, dodaj tu zeby zlapac przed lintem
  @{ Pattern = '^\s*app-[\w-]+\.[\w-]+\s';                                                              Msg = 'SCSS: NIE qualifying type selector (`app-foo.bar`). Uzyj samej klasy `.bar` (selector-no-qualifying-type)'; Kinds = @('scss') }

  # TS — cast hacks
  @{ Pattern = '\bas\s+unknown\s+as\b';                                                                 Msg = 'TS: NIGDY `as unknown as X` - to maskowanie typu. Fix the type (zob. typescript.md anty-wzorce)'; Kinds = @('ts','spec') }
  @{ Pattern = '\bas\s+any\b';                                                                          Msg = 'TS: NIGDY `as any` - to maskowanie typu. Uzyj `unknown` + narrow (zob. typescript.md anty-wzorce)'; Kinds = @('ts','spec') }

  # Spec — query rules
  @{ Pattern = '\.querySelector(All)?\s*\(';                                                            Msg = 'Spec: NIGDY querySelector(All) - query po byTestId(''X'') lub spectator.query(Component) (zob. angular.md "Selektory w testach")'; Kinds = @('spec') }
  @{ Pattern = "spectator\.query\s*\(\s*['""][.#\[]";                                                   Msg = 'Spec: NIE query CSS selektorem (klasa/id/atrybut). Uzyj byTestId(''X'') lub Component type'; Kinds = @('spec') }

  # Spec — inline dummy data zabronione (musi byc w shared fake-data per konwencja projektu)
  @{ Pattern = '\b(const|let)\s+dummy[A-Z]\w*\s*[:=]';                                                  Msg = 'Spec: NIGDY inline dummy w spec - wynies do shared fake-data zgodnie z konwencja projektu (zob. <projekt>/CLAUDE.md sekcja Mock data)'; Kinds = @('spec') }
)

$violations = @()

foreach ($t in (Get-EditTargets -Payload $payload)) {
  $norm = Resolve-NormalizedPath -Path $t.FilePath
  if (-not $norm) { continue }
  $project = Get-ProjectId -NormalizedPath $norm
  if (-not $project) { continue }  # nie nasz projekt

  $kind = Get-FileKind -NormalizedPath $norm
  if ($kind -eq 'other') { continue }

  $rules = if ($project -eq 'suite') { $AntiPatternsSuite } else { $AntiPatternsFrontend }

  foreach ($r in $rules) {
    if ($kind -notin $r.Kinds) { continue }
    if ($r.PathExclude -and $norm -match $r.PathExclude) { continue }
    if ($t.Content -match $r.Pattern) {
      $violations += "[$project/$kind] $($r.Msg)  (regex: $($r.Pattern))"
    }
  }
}

if ($violations.Count -eq 0) {
  exit 0
}

# Zbuduj komunikat blokady
$reason = "Wykryto naruszenie regul projektu (CLAUDE.md). Popraw kod ZGODNIE z regulami:`n`n" + ($violations -join "`n")

$response = @{
  hookSpecificOutput = @{
    hookEventName            = 'PreToolUse'
    permissionDecision       = 'deny'
    permissionDecisionReason = $reason
  }
}
$response | ConvertTo-Json -Depth 5 -Compress
[Console]::Error.WriteLine($reason)
exit 2
