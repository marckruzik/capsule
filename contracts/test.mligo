#import "ligo-breathalyzer/lib/lib.mligo" "Breath"
#import "benefactor/test.mligo" "Benefactor_test"

let () = 
  Breath.Model.run_suites Trace [
    Benefactor_test.suite
  ]