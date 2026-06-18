///|
test "disposable is idempotent" {
  let count = Ref(0)
  let disposable = Disposable::from(() => count.val = count.val + 1)
  disposable.dispose()
  disposable.dispose()
  assert_eq(count.val, 1)
}

///|
test "emitter listener disposable removes only that listener" {
  let emitter : Emitter[String] = Emitter::new()
  let first = Ref("")
  let second = Ref("")
  let first_subscription = emitter.event(value => first.val = first.val + value)
  let second_subscription = emitter.event(value => {
    second.val = second.val + value
  })
  emitter.fire("a")
  first_subscription.dispose()
  emitter.fire("b")
  second_subscription.dispose()
  emitter.fire("c")
  assert_eq(first.val, "a")
  assert_eq(second.val, "ab")
}

///|
test "emitter dispose stops active and later listeners" {
  let emitter : Emitter[String] = Emitter::new()
  let seen = Ref("")
  emitter.event(value => seen.val = seen.val + value).dispose()
  emitter.event(value => seen.val = seen.val + value) |> ignore
  emitter.fire("a")
  emitter.dispose()
  emitter.event(value => seen.val = seen.val + value) |> ignore
  emitter.fire("b")
  assert_eq(seen.val, "a")
}
