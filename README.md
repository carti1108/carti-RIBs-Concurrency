# MicroRIBs

Uber의 [RIBs](https://github.com/uber/RIBs-iOS) 아키텍처를 Swift Concurrency 중심으로 재구성.

## 목표

- 원본 RIBs의 `Interactor`, `Router`, `ViewableRouter`, `Worker`, `Workflow` 구조 유지
- 메인 스레드 관례를 `@MainActor`로 명시
- RxSwift의 `Subject`, `Observable`, `Disposable` 의존성 제거
- Swift 6 strict concurrency 환경에서도 자연스럽게 동작하도록 정리

## 원본 RIBs Rx 코드 치환 기준

원본 RIBs가 기대하던 동작을 Swift Concurrency로 옮기는 방향으로 마이그레이션.

핵심 원칙은 아래와 같음.

- `BehaviorSubject`의 "현재 값 보관 + 구독 즉시 최신 값 replay" 동작은 `CurrentValueAsyncStream`으로 치환
- `PublishSubject`의 "현재 값 없이 이벤트만 브로드캐스트" 동작은 `PassthroughAsyncSubject`로 치환
- `CompositeDisposable`의 "여러 subscription 수명 관리"는 `CompositeCancellable`로 치환
- `DisposeBag` 스타일 소유권 관리는 `AnyCancelTaskBag`으로 치환
- `Observable` chain은 가능한 범위에서 `AsyncSequence` + `swift-async-algorithms` 조합으로 치환
- 기존의 main-thread-only 관례는 `@MainActor`로 타입 시스템에 반영

## RxSwift -> Swift Concurrency 치환 매핑

| 원본 RIBs Rx 코드 | Swift Concurrency 코드 | 동작 설명 |
| --- | --- | --- |
| `BehaviorSubject<Bool>(value: false)` | `CurrentValueAsyncStream<Bool>(false)` | 현재 값 저장 + 새 subscriber에 최신 값 즉시 replay 용도 |
| `BehaviorRelay<Int>(value: 0)` | `CurrentValueAsyncStream<Int>(0)` | 에러 채널 없는 최신 값 저장소 용도 |
| `PublishSubject<RouterLifecycle>()` | `PassthroughAsyncSubject<RouterLifecycle>()` | replay 없는 이벤트 브로드캐스트 용도 |
| `Observable<Element>` | `AsyncStream<Element>` | 비동기 값 흐름 표현 |
| `CompositeDisposable` | `CompositeCancellable` | 여러 task-like 객체 일괄 취소 용도 |
| `DisposeBag` | `AnyCancelTaskBag` | 외부 task lifetime을 객체 소유권에 묶는 용도 |
| `Disposable.dispose()` | `Task.cancel()` | 개별 작업 종료 |
| `disposable.disposeOnDeactivate(interactor:)` | `task.cancelOnDeactivate(interactor:)` | interactor 비활성화 시 task 취소 |
| `disposable.disposeOnStop(worker:)` | `task.cancelOnStop(worker:)` | worker 중지 시 task 취소 |
| `Observable.combineLatest(a, b)` | `AsyncAlgorithms.combineLatest(a, b)` | 두 비동기 시퀀스 최신값 조합 |
| `.filter { ... }` | `.filter { ... }` | 동일 의미 유지 |
| `.map { ... }` | `.map { ... }` | 동일 의미 유지 |
| `.distinctUntilChanged()` | `.removeDuplicates()` | 연속 중복 이벤트 제거 |
| `subject.onNext(value)` | `subject.send(value)` | 새 값 발행 |
| `subject.onCompleted()` | `subject.finish()` | 스트림 종료 |

## 동작별 구현 방식

### `BehaviorSubject` 치환

RIBs는 `Interactor.isActiveStream`, `Worker.isStartedStream`처럼 "현재 상태를 가지고 있고, 구독하자마자 최신 값을 즉시 전달하는" stream에 의존.

예시:

```swift
private let isActiveSubject = BehaviorSubject<Bool>(value: false)
var isActiveStream: Observable<Bool> { isActiveSubject.asObservable() }
```

이를 [CurrentValueAsyncStream](Sources/MicroRIBs/Extension/CurrentValueAsyncStream.swift)으로 치환.

```swift
private let isActiveSubject = CurrentValueAsyncStream<Bool>(false)
var isActiveStream: AsyncStream<Bool> { isActiveSubject.stream }
```

이 타입은 아래 동작을 구현함.

- 현재 값을 내부에 저장
- subscriber가 붙을 때 최신 값을 즉시 `yield`
- 이후 `send(_:)` 호출 때마다 모든 subscriber에게 새 값 브로드캐스트
- `finish()` 호출 시 모든 subscriber 종료

RIBs가 `Router`, `ViewableRouter`, `Worker`에서 "구독 직후 current state를 즉시 받는다"는 Rx semantics에 기대고 있기 때문에 이 동작이 중요함.

### `PublishSubject` 치환

`Router.lifecycle` 같은 스트림은 현재 값을 replay할 필요 없이 이벤트만 흘리면 됨.

예시:

```swift
private let lifecycleSubject = PublishSubject<RouterLifecycle>()
```
이를 [PassthroughAsyncSubject](Sources/MicroRIBs/Extension/PassthroughAsyncSubject.swift)로 치환.

```swift
private let lifecycleSubject = PassthroughAsyncSubject<RouterLifecycle>()
```

이 타입은 아래 동작을 구현.

- 현재 값 저장 없음
- `send(_:)` 시점에 현재 subscriber들에게만 이벤트 전달
- `finish()` 시 전체 종료

### `CompositeDisposable` 치환

RIBs는 interactor deactivate, worker stop, router deinit 시점에 여러 subscription을 한 번에 dispose함.

예시:

```swift
private var disposable: CompositeDisposable?
```

이를 [CompositeCancellable](Sources/MicroRIBs/Extension/CompositeCancellable.swift)로 치환.

```swift
private var workerCancellable: CompositeCancellable?
```

구현 의도는 같음.

- 여러 task-like 객체 저장
- 생명주기 종료 시 `cancel()` 한 번으로 전체 정리
- 이미 종료된 뒤 insert되면 즉시 cancel

### `DisposeBag` 치환

Rx 코드는 객체 소유권에 subscription lifetime을 묶기 위해 `DisposeBag`을 자주 씀.

이를 [AnyCancelTaskBag](Sources/MicroRIBs/Extension/AnyCancelTaskBag.swift)을 사용함.

```swift
let task = Task { ... }
task.store(in: bag)
```

의미는 Rx의 아래 코드와 같음.

```swift
disposable.disposed(by: disposeBag)
```

### `Observable` chain 치환

RIBs의 `confineTo`는 아래처럼 구현되어 있음.

```swift
Observable
    .combineLatest(interactorScope.isActiveStream, self)
    .filter { isActive, _ in isActive }
    .map { _, value in value }
```

이 프로젝트는 `swift-async-algorithms`의 `combineLatest`와 `AsyncSequence` 연산을 사용해 같은 의미를 구현.

```swift
combineLatest(interactorScope.isActiveStream, self)
    .filter { isActive, _ in isActive }
    .map { _, value in value }
    .eraseToStream()
```

관련 구현은 [Interactor.swift](Sources/MicroRIBs/Interactor.swift)와 [AsyncSequence+.swift](Sources/MicroRIBs/Extension/AsyncSequence+.swift).

### `disposeOnDeactivate` / `disposeOnStop` 치환

RIBs는 `Disposable`을 특정 lifecycle에 묶는 helper를 제공.

```swift
subscription.disposeOnDeactivate(interactor: interactor)
subscription.disposeOnStop(worker)
```

이 프로젝트에서는 `Task` 취소 기반으로 바꿈.

```swift
task.cancelOnDeactivate(interactor: interactor)
task.cancelOnStop(worker)
```

이 helper들은 내부적으로 `Interactor`의 `activenessCancellables`, `Worker`의 `workerCancellable`에 자신을 등록하고, lifecycle 종료 시 일괄 취소됨.

## MainActor 격리 정리

### 이유

`RIBs`의 core 타입들은 원래부터 사실상 main thread 전용 규약으로 쓰이던 코드임.

- builder는 main에서 생성
- router는 main에서 attach/detach
- interactor는 main에서 activate/deactivate
- worker는 main에서 start/stop
- view 관련 타입은 당연히 main 문맥 전제

예전에는 이 규약이 "관례"로만 존재했음.

Swift 6 strict concurrency에서는 이런 관례만으로는 부족함. shared mutable state와 lifecycle mutation이 actor isolation 없이 노출되면 바로 컴파일 에러로 이어짐.

그래서 이 저장소는 `nonisolated`로 우회하지 않고, 실제 사용 모델에 맞춰 `@MainActor`를 붙이는 방향을 택함.

### 적용 위치

`@MainActor`는 framework core 전반에 적용함.

- DI: `Buildable`, `Builder`, `Dependency`, `EmptyDependency`, `Component`, `EmptyComponent`
- lifecycle: `InteractorScope`, `Interactable`, `Interactor`
- presenter: `Presentable`, `Presenter`, `PresentableInteractor`
- router: `RouterLifecycle`, `RouterScope`, `Routing`, `Router`, `ViewableRouting`, `ViewableRouter`, `LaunchRouting`, `LaunchRouter`
- view: `ViewControllable`
- worker: `Working`, `Worker`
- workflow: `Workflow`, `Step`
- leak detection: `LeakDetector`

extension helper도 같은 문맥으로 맞춤.

- `confineTo`
- `cancelOnDeactivate`
- `cancelOnStop`
- `disposeWith`

### `isolated deinit`을 쓴 이유

몇몇 타입은 deinit 안에서 main actor 격리 API를 직접 호출함.

예시:

- `deactivate()`
- `LeakDetector.instance.expectDeallocate(...)`

이런 타입은 일반 deinit으로 두면 strict concurrency에서 안전하지 않음.

그래서 아래 타입에는 `isolated deinit` 적용함.

- `Interactor`
- `PresentableInteractor`
- `Router`
- `ViewableRouter`
- `Worker`

즉 teardown도 main actor 문맥에서 끝까지 정리되도록 맞춤.

`isolated deinit`은 Swift 6.1 런타임이 필요해서 최소 지원 버전은 iOS 18.4 / macOS 15.4, 빌드 도구는 Swift 6.2 이상임. `MainActor.assumeIsolated`로 대신하면 마지막 참조가 메인 스레드 밖에서 풀릴 때 크래시하므로 쓰지 않음.

## 구현상 주의한 점

### Rx의 동기 전달 semantics 유지

`Task { for await ... }`만으로 Rx `BehaviorSubject` 구독을 대신할 수는 없음.

- Rx 구독은 `onNext`와 같은 호출 스택에서 실행됨. 부모 `deactivate()`가 반환되기 전에 하위 트리 전체가 비활성화됨.
- `Task`로 전달하면 한 번 넘어가서 늦게 처리되고, 빠른 `false → true` 변화가 합쳐져 `willResignActive`/`didStop` 같은 콜백이 빠질 수 있음.
- `Task`가 `self`를 강하게 잡은 채 끝나지 않는 스트림을 돌면 router가 해제되지 않는 순환 참조가 생김.

그래서 생명주기 전파는 `InteractorScope.observeActiveState(_:)`로 동기 관찰함.

- `ActiveStateRelay`가 현재 값, 동기 옵저버 목록, `AsyncStream`을 함께 가짐.
- 옵저버는 등록 즉시 현재 값을 받고, 이후 `send(_:)`가 반환되기 전에 등록 순서대로 호출됨.
- `ActiveStateObservation`은 `cancel()`하거나 해제되면 관찰을 끝냄. 옵저버 클로저는 대상을 `weak`로 잡음.
- `Router`의 subtree active state 전파, `ViewableRouter`의 leak detection, `Worker`의 start/stop이 이 방식을 씀.
- `isActiveStream`은 `confineTo`, `Workflow`처럼 외부에서 비동기로 관찰하는 용도로 남김.

`InteractorScope`를 직접 구현하는 타입은 `ActiveStateRelay`를 두고 `observeActiveState`를 `relay.observe(_:)`로 넘기면 됨.

## 참고 출처

- [uber/RIBs-iOS PR #49](https://github.com/uber/RIBs-iOS/pull/49)

## 라이선스

MicroRIBs는 [uber/RIBs-iOS](https://github.com/uber/RIBs-iOS)(Copyright (c) 2017 Uber Technologies)를 바탕으로 RxSwift 의존성을 Swift Concurrency로 바꾼 파생 프로젝트이며, 원본과 같은 Apache License 2.0으로 배포합니다. 원본에서 가져와 수정한 파일에는 원본 저작권 고지와 수정 사실을 남겼습니다. 전문은 [LICENSE.txt](LICENSE.txt)를 참고하세요.

MicroRIBs는 Uber의 공식 프로젝트가 아닙니다.
