// Exact trace oracle: `vscode/src/vs/base/test/browser/ui/scrollbar/
// scrollableElement.test.ts` in the checked-in source.
// The test loader reads the pinned submodule so the nine source traces remain
// byte-owned by upstream instead of being copied and silently drifting here.

///|
fn run_classifier_trace(
  label : String,
  expected_physical : Bool,
  skip_first? : Bool = false,
) -> Unit raise {
  let classifier = MouseWheelClassifier()
  let trace = load_classifier_trace(label)
  assert_true(trace.length() > 0)
  for index, event in trace {
    classifier.accept(event[0], event[2], event[1])
    if !skip_first || index > 0 {
      assert_eq(classifier.is_physical_mouse_wheel(), expected_physical)
    }
  }
}

///|
test "upstream classifier trace: OSX - Apple Magic Mouse" {
  run_classifier_trace("OSX - Apple Magic Mouse", false)
}

///|
test "upstream classifier trace: OSX - Apple Touch Pad" {
  run_classifier_trace("OSX - Apple Touch Pad", false)
}

///|
test "upstream classifier trace: OSX - Razer Physical Mouse Wheel" {
  run_classifier_trace("OSX - Razer Physical Mouse Wheel", true)
}

///|
test "upstream classifier trace: Windows - Microsoft Arc Touch" {
  run_classifier_trace("Windows - Microsoft Arc Touch", true)
}

///|
test "upstream classifier trace: Windows - SurfaceBook TouchPad" {
  run_classifier_trace("Windows - SurfaceBook TouchPad", false)
}

///|
test "upstream classifier trace: Windows - Razer physical wheel" {
  run_classifier_trace("Windows - Razer physical wheel", true)
}

///|
test "upstream classifier trace: Windows - Logitech physical wheel" {
  run_classifier_trace("Windows - Logitech physical wheel", true)
}

///|
test "upstream classifier trace: Windows - Microsoft basic v2 physical wheel" {
  run_classifier_trace("Windows - Microsoft basic v2 physical wheel", true)
}

///|
test "upstream classifier trace: Linux Wayland - Logitech G Pro Wireless" {
  run_classifier_trace(
    "Linux Wayland - Logitech G Pro Wireless",
    true,
    skip_first=true,
  )
}

///|
extern "js" fn load_classifier_trace(label : String) -> Array[Array[Double]] =
  #| (label) => {
  #|   const fs = process.getBuiltinModule('fs');
  #|   const path = process.getBuiltinModule('path');
  #|   const source = fs.readFileSync(path.join(
  #|     process.cwd(),
  #|     'vscode' + '/src/vs/base/test/browser/ui/scrollbar/scrollableElement.test.ts'
  #|   ), 'utf8');
  #|   const escaped = label.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  #|   const section = source.match(new RegExp(
  #|     `test\\('${escaped}'[\\s\\S]*?const testData:[^=]+=[\\s]*\\[([\\s\\S]*?)\\];`
  #|   ));
  #|   if (!section) throw new Error(`missing upstream classifier trace: ${label}`);
  #|   return Array.from(section[1].matchAll(
  #|     /\[\s*(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)\s*\]/g
  #|   ), match => [Number(match[1]), Number(match[2]), Number(match[3])]);
  #| }
