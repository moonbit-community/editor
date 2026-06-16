///|
pub(all) struct BrowserTestContext {
  suite : String
  failures : Array[String]
  metrics : Map[String, Json]
}

///|
pub fn BrowserTestContext::new(suite : String) -> BrowserTestContext {
  { suite, failures: [], metrics: {} }
}

///|
pub fn BrowserTestContext::fail(
  self : BrowserTestContext,
  message : String,
) -> Unit {
  self.failures.push(message)
}

///|
pub fn BrowserTestContext::assert_true(
  self : BrowserTestContext,
  condition : Bool,
  message : String,
) -> Unit {
  if !condition {
    self.fail(message)
  }
}

///|
pub fn BrowserTestContext::metric(
  self : BrowserTestContext,
  name : String,
  value : Json,
) -> Unit {
  self.metrics[name] = value
}

///|
pub fn BrowserTestContext::metric_int(
  self : BrowserTestContext,
  name : String,
  value : Int,
) -> Unit {
  self.metric(name, value.to_json())
}

///|
pub fn BrowserTestContext::metric_number(
  self : BrowserTestContext,
  name : String,
  value : Double,
) -> Unit {
  self.metric(name, Json::number(value))
}

///|
pub fn BrowserTestContext::metric_string(
  self : BrowserTestContext,
  name : String,
  value : String,
) -> Unit {
  self.metric(name, value.to_json())
}

///|
pub fn BrowserTestContext::to_json(self : BrowserTestContext) -> Json {
  {
    "suite": self.suite.to_json(),
    "status": (if self.failures.length() == 0 { "passed" } else { "failed" }).to_json(),
    "failures": Json::array(self.failures.map(failure => failure.to_json())),
    "metrics": Json::object(self.metrics),
  }
}

///|
pub fn BrowserTestContext::finish(self : BrowserTestContext) -> Unit {
  report_json(self.to_json().stringify())
}
