; ==============================================================
; ==============      DEFINITIONS        =======================
; ==============================================================

globals [
  currently-overflowing
  tasks-overflowed
  tasks-finished   ; a list containing a counter for each difficulty
  max-capacity     ; the max number of task a agent can hold
  fired            ; the count of fired nodes
  hired            ; the count of fired nodes
  fired-ages       ; list of ages from all nodes that where fired
  ages             ; for plotting after n rounds with nodes alive
  total-idle-time  ; the number of rounds a node can be idle for until fired
  num-nodes        ; list of counts for each round

  min-value        ; min number of difficulty levels (mainly for node coloring)
  max-value        ; max number of difficulty levels (mainly for node coloring)

  n-tasks          ; counter wieviele tasks gabs
  fin-ttl          ; wie lange lebt in der regel ein task

  LOGGING_LEVELS   ; Logging level "INFO" "DEBUG" "WARN" "ERROR"
]

breed [ nodes node ]
nodes-own [
  stack-of-tasks   ; a list of tasks
  working-on       ; task that is the agent is working on
  idle-time        ; number of rounds a node was idle, sets back to 0 when working
  capability       ; vector defining capabiloty strength (currently 3 dimensions)
  experience       ; number of tasks finished
  age              ; nuber of rounds the node has lived for
  angle            ; for visualisation
  cap-updates      ; all capability updates (times x capability vector)
]

breed [ tasks task ]
tasks-own [
  task-type        ; a vector defining the difficulty of the task (currently 3 dimensional)
  age              ; number of rounds the task has lived for
  initial-time     ; number of rounds the node needs to finish the task
  time-left        ; number of rounds left for the node to finish the task
]


; ==============================================================
; ==============     MAIN SIMULATION FLOW        ===============
; ==============================================================


to setup
  clear-all
  reset-ticks
  set-default-shape nodes "circle"
  set-default-shape tasks "triangle"
  setup-logging


  set tasks-overflowed [0 0 0 0 0]
  set tasks-finished [0 0 0 0 0]
  set n-tasks [0 0 0 0 0]
  set fin-ttl [0 0 0 0 0]
  set max-capacity 5
  set min-value 1
  set max-value 5
  set fired-ages []
  set currently-overflowing 0
  set fired 0
  set total-idle-time 0
  set num-nodes []
  setup-nodes number-of-nodes

  setup-plots
  layout
end


to go
  tick
  LOGGER "INFO" (word "========== ROUND " ticks " ==========")
  if currently-overflowing > 0 [
    LOGGER "INFO" (word "Adding " currently-overflowing " new agents due to task overflow.")
    setup-nodes currently-overflowing
    set hired hired + currently-overflowing
    set currently-overflowing 0 ;
  ]
  instantiate-tasks number-of-tasks
  agent-loop
  tasks-maintanance
  set num-nodes fput count nodes num-nodes
  layout
  LOGGER "INFO" (word "============= END " ticks " ==========")
  if ticks >= stop-at-ticks [
    stop
  ]
end

to tasks-maintanance
  ask tasks [
    set age age + 1
  ]
end

; ==============================================================
; ==============     SETUP & REPORTERS        ==================
; ==============================================================

to setup-nodes [ n ]
  create-nodes n [
    ; defining the fix parameters each node has when created
    set stack-of-tasks []
    set working-on nobody
    set idle-time 0
    set experience 0
    set age 0

    ; setting the initial capabilitie vector
    set capability (list
      (2.5)
      (2.5)
      (2.5)
    )

    ; add initial capability vector in the update list
    set cap-updates []
    set cap-updates lput capability cap-updates

    ; get nodes that have at max num_links and are not linked to the node already
    let candidates other nodes with [count my-links < num_links and not link-neighbor? myself]

    ; olny select as many link partners as needed to reach num_links connections
    let selected-partners n-of min list (num_links - count my-links) count candidates candidates

    ask selected-partners [
      create-link-with myself
    ]

    LOGGER "INFO" ( word "created node " self " with " count my-links " collegues")
  ]

  ; Optional: Label each node with its link count for verification
  ask nodes [ set label count my-links ]
  ask links [ set hidden? false ]
end


to instantiate-tasks [ n ]
  create-tasks n [
    let difficulty random 5 + 1
    set task-type one-of [ [0 0 1] [0 1 0] [1 0 0] ]
    set size 0.5

    set task-type (map [ x -> x * difficulty ] task-type)
    set age 0

    let tdif difficulty - 1
    set n-tasks replace-item tdif n-tasks (item tdif n-tasks + 1)
    assign-task-to-node self
  ]
end



to assign-task-to-node [ t ]
  let target-node one-of nodes
  ask target-node [
    set stack-of-tasks lput t stack-of-tasks
    LOGGER "INFO" (word "Received task " t " of type " [task-type] of t)
  ]
end


to-report total-tasks-overflowed
  report sum tasks-overflowed
end

to-report total-tasks-finished
  report sum tasks-finished
end

to-report tasks-completed-difficulty-1
  report item 0 tasks-finished
end

to-report tasks-completed-difficulty-2
  report item 1 tasks-finished
end

to-report tasks-completed-difficulty-3
  report item 2 tasks-finished
end

to-report tasks-completed-difficulty-4
  report item 3 tasks-finished
end

to-report tasks-completed-difficulty-5
  report item 4 tasks-finished
end


to-report avg-task-age
  ifelse any? tasks [
    report (sum [age] of tasks) / count tasks
  ] [
    report 0
  ]
end

to print-node-capabilities
  ask nodes [
    LOGGER "INFO" (word map [x -> precision x 2] capability)
  ]
end

to setup-logging
  set LOGGING_LEVELS ["INFO" "DEBUG" "WARN" "ERROR"]
end

to LOGGER [ level message ]
  if LOGGING and member? level LOGGING_LEVELS [
    show (word "[" level "] Tick " ticks ": " message)
  ]
end

; ==============================================================
; ================     Visualization        ====================
; ==============================================================

to layout
  let sorted-nodes sort nodes
  let node-count length sorted-nodes
  foreach sorted-nodes [n ->
    ask n [
      let index position n sorted-nodes
      let r scale-component (item 0 capability)
      let g scale-component (item 1 capability)
      let b scale-component (item 2 capability)
      let radius 8
      set color rgb r g b
      set angle 360 / node-count * index
      setxy (radius * cos angle) (radius * sin angle)
      move-task-to-node self
    ]
  ]

  ; for plotting
  set ages fired-ages
  ask nodes [
    set ages fput age ages
  ]
end

to-report scale-component [value]
  report round (255 * ((value - min-value) / (max-value - min-value)))
end

to move-task-to-node [n]
  if [working-on] of n != nobody [
    ask [working-on] of n [
      move-to n
    ]
  ]
  let radius 9
  foreach [stack-of-tasks] of n [ x ->
    let posx (radius * cos [angle] of n)
    let posy (radius * sin [angle] of n)
    ask x [
      setxy posx posy

      set color rgb (item 0 task-type * 255) (item 1 task-type * 255) (item 2 task-type * 255)
    ]
    set radius radius + 0.5
  ]
end


; ==============================================================
; ==============       AGENT FUNCTIONS           ===============
; ==============================================================


to agent-loop
  exchange-new-tasks


  ask nodes [
    ; tracks how many round the node lived for
    set age age + 1
    reason self
  ]
end

to exchange-new-tasks
  let old-tasks-discarded  sum tasks-overflowed
  ask nodes [
    if length stack-of-tasks > max-capacity [
      handle-random-task-assigned-overflow self
    ]
  ]
  let lost-this-round  sum tasks-overflowed - old-tasks-discarded
  if lost-this-round > 0 [
    set currently-overflowing lost-this-round
  ]
end


to reason [ agent ]
  ask agent [
    if length stack-of-tasks = 0 and working-on = nobody [
      ask-for-task self
    ]
    if length stack-of-tasks > 0 and working-on = nobody [
      start-working self
    ]

    ifelse working-on != nobody [
      ask working-on [
        set time-left time-left - 1
      ]

      LOGGER "INFO" ( word "working on task " working-on " time left " [time-left] of working-on )
      if [time-left] of working-on = 0 [
        let tdif sum [task-type] of working-on
        set tdif tdif - 1
        set tasks-finished replace-item tdif tasks-finished (item tdif tasks-finished + 1)

        set fin-ttl replace-item tdif fin-ttl (item tdif fin-ttl + [age] of working-on)

        LOGGER "INFO" (word "Finished task " working-on)
        update-capabilities self working-on



        ask working-on [
          die
        ]
        set working-on nobody
        set idle-time 0
        set experience experience + 1
      ]

    ] [
      if idle-time = max-idle-time [
        LOGGER "INFO" (word "Was idle for too long will die")
        set fired fired + 1
        set fired-ages fput age fired-ages
        die
      ]
      set idle-time idle-time + 1
    ]

  ]
end

; vieleicht den task discarden den man am wenigsten mag
to handle-random-task-assigned-overflow [ agent ]
  let available-nodes nodes with [self != agent and length stack-of-tasks < max-capacity and member? self [link-neighbors] of agent ]
  let overflowing-task last [ stack-of-tasks ] of agent

  ask agent [
    set stack-of-tasks but-last stack-of-tasks
  ]

  ; gib task jemandem mit wenig arbeit + capability
  ifelse count available-nodes > 0 [
    give-task-to-node-with-least-tasks available-nodes overflowing-task self
  ]
  ; else if no one has any capacity task will go to waste
  [
    LOGGER "INFO" (word "Asked " count [ link-neighbors ] of agent " Collegues, found no one to solve " overflowing-task " discarding.")
    let tdif sum [task-type] of overflowing-task
    set tdif tdif - 1
    set tasks-overflowed replace-item tdif tasks-overflowed (item tdif tasks-overflowed + 1)

    ask overflowing-task [
      die
    ]
  ]
end



to give-task-to-node-with-least-tasks [ agents t from ]
  let node-with-smallest-stack min-one-of agents [length stack-of-tasks]

  ask node-with-smallest-stack [
    set stack-of-tasks lput t stack-of-tasks
    LOGGER "INFO" (word "Received Task " t " from " from ".")
  ]
end

to-report want-task [agent t ]
  ; if i am generalist e.g. have no preference yet just early exit and say yes
  let best-at max [ capability ] of agent
  let worst-at min [ capability ] of agent

  ifelse best-at - worst-at < 1 [
    report true
  ] [

    let want false
    let max-index position best-at [ capability ] of agent

    let t-type max [ task-type ] of t
    let t-index position t-type [ task-type ] of t

    if max-index = t-index [
      set want true
    ]
    report want
  ]
end

; checks if the node we want task t from actually wants to give it to us
to-report give-task [ agent t ]
  let want true
  let best-at max [ capability ] of agent
  let max-index position best-at [ capability ] of agent

  let t-type max [ task-type ] of t
  let t-index position t-type [ task-type ] of t

  ask agent [
    ;
    ;if working-on = nobody and length stack-of-tasks < 2 [
    ; set want false
    ;]
    if idle-time < 0 [
      set want false
    ]
  ]

  if max-index = t-index [
    set want false
  ]

  report want
end

; If our agent has no work he will ask his collegues for open tasks.
; He simply goes through the stack of the other person and if he sees a task he wants to do he takes it
to ask-for-task [ agent ]
  let others-with-tasks sort ( nodes with [self != agent and length stack-of-tasks > 0 and member? self [link-neighbors] of agent ] ); here we just take the smaller collection of nodes he knows

  let found-task false
  while [ length others-with-tasks > 0 ] [
    let some-node first others-with-tasks
    set others-with-tasks but-first others-with-tasks

    let tasks-of-collegue [ stack-of-tasks ] of some-node


    foreach tasks-of-collegue [
      t ->
      if want-task agent t [
        LOGGER "INFO" (word "want the task " t " from node " some-node)
        if give-task some-node t [
          ask some-node [
            set stack-of-tasks remove t stack-of-tasks
          ]
          ask agent [
            set stack-of-tasks lput t stack-of-tasks
          ]
          set found-task true
          LOGGER "INFO" (word "Got task " t " from node " some-node " - due to no work." )
        ]
      ]
      if found-task [ stop ]
    ]
    if found-task [ stop ]
  ]
  if not found-task [ LOGGER "INFO" (word "no work left for me to do") ]
end

to-report get-task-from-agent [a1 a2]
  let received-task nobody
  let best-c 0
  foreach [stack-of-tasks] of a2 [ t ->
    let c1 sum ( map [[x y] -> x * y] [capability] of a1 [task-type] of t )
    let c2 sum ( map [[x y] -> x * y] [capability] of a2 [task-type] of t )
    if c1 > c2 and c1 > best-c [
      set received-task t
      set best-c c1
    ]
  ]
  report received-task
end

to-report ask-links-if-better [a t]
  let best-al nobody
  let best-c sum ( map [[x y] -> x * y] [capability] of a [task-type] of t )
  ask [link-neighbors] of a [
    let c sum ( map [[x y] -> x * y] capability [task-type] of t )
    if best-c < c and length stack-of-tasks < 5 [
      set best-al self
      set best-c c
    ]
  ]
  report best-al
end



to start-working [ agent ]
  while [[ working-on ] of agent = nobody and length [stack-of-tasks] of agent > 0][
    let nextTask last [stack-of-tasks] of agent
    ask agent [
      set stack-of-tasks but-last stack-of-tasks
    ]

    if want-task agent nextTask [
      let task-time sum (map [ [ x y ] -> x + x / y ] [task-type] of nextTask [ capability ] of agent)

      ask nextTask [
        set initial-time floor task-time
        set time-left initial-time
      ]

      ask agent [
        set working-on nextTask
        set idle-time 0
        LOGGER "INFO" (word "Want to do this task - Starting work on " working-on  " expected time " [initial-time] of working-on)
      ]
      stop
    ]

    if not want-task agent nextTask [
      let collegues sort ( nodes with [ self != agent and length stack-of-tasks < max-capacity and member? self [link-neighbors] of agent ] )
      let passed-on false
      foreach collegues [
        collegue ->
        if want-task collegue nextTask and passed-on = false [
          ask collegue [
            set stack-of-tasks lput nextTask stack-of-tasks
          ]
          set passed-on true
          LOGGER "INFO" (word "Collegue " collegue " took task " nextTask " off me.")
        ]
      ]

      if not passed-on [
        let task-time sum (map [ [ x y ] -> x + x / y ] [task-type] of nextTask [ capability ] of agent)

        ask nextTask [
          set initial-time floor task-time
          set time-left initial-time
        ]
        ask agent [
          set working-on nextTask
          set idle-time 0
          LOGGER "INFO" (word "Did not want this task - Starting work on " working-on  " expected time " [initial-time] of working-on)
        ]
      ]
    ]
  ]
  if [ working-on ] of agent = nobody [ LOGGER "INFO" ( word "passed on all my work to other agents")]
end


; ==============================================================
; ===========       LEARNING FUNCTIONS           ===============
; ==============================================================


to update-capabilities [current-node task-node]
  ; Update capabilities based on learning type

  update-capability-balanced current-node working-on

  ; update color
  let r scale-component (item 0 capability)
  let g scale-component (item 1 capability)
  let b scale-component (item 2 capability)
  ask current-node [
    set color rgb r g b
  ]

end


to-report adjust-capabilities [old-capability tentative-new-capability]
  let sum-old sum old-capability
  let new-capability map [ x -> max list 1 (min list 5 x) ] tentative-new-capability
  let sum-new sum new-capability
  let delta-sum sum-new - sum-old

  if abs delta-sum < 0.0001 [ report new-capability ]

  let indices range length new-capability

  ifelse delta-sum > 0 [
    ; Need to decrease capabilities
    let adjustable-indices filter [ i -> item i new-capability > 1 ] indices
    let total-decrease sum map [ i -> (item i new-capability) - 1 ] adjustable-indices
    if total-decrease = 0 [ report new-capability ]  ; No room to adjust

    let factor delta-sum / total-decrease
    foreach adjustable-indices [i ->
      let cap item i new-capability
      let reduction factor * (cap - 1)
      set new-capability replace-item i new-capability (cap - reduction)
    ]
  ] [
    ; Need to increase capabilities
    let adjustable-indices filter [ i -> item i new-capability < 5 ] indices
    let total-increase sum map [ i -> 5 - (item i new-capability) ] adjustable-indices
    if total-increase = 0 [ report new-capability ]  ; No room to adjust

    let factor (- delta-sum) / total-increase
    foreach adjustable-indices [i ->
      let cap item i new-capability
      let increment factor * (5 - cap)
      set new-capability replace-item i new-capability (cap + increment)
    ]
  ]

  report new-capability
end



; Balanced Learning
to update-capability-balanced [current-node task-node]
  let old-capability [capability] of current-node
  let task-requirement [task-type] of task-node

  ; Step 1: Calculate desired changes
  let delta-capability map [ x -> alpha * (item x task-requirement - item x old-capability)] (range length old-capability)

  ; Step 2: Apply tentative changes
  let tentative-new-capability map [ x -> item x old-capability + item x delta-capability  ] (range length old-capability)

  ; Step 3 & 4: Adjust capabilities to preserve total sum and stay within bounds
  let new-capability adjust-capabilities old-capability tentative-new-capability

  ask current-node [
    LOGGER "INFO" (word "=> UPDATE CAPABILITY: " map [ x -> precision x 2] capability " to " map [ x -> precision x 2] new-capability)
    set capability new-capability
    ; add the new capability to the update list
    set cap-updates lput capability cap-updates
  ]
end


; ==============================================================
; =========       Specialization Metrics           =============
; ==============================================================

to compute-balence-scores
  let balance-scores []
  ask nodes [
    ;; Balance Score: Standard deviation of the current capability vector
    let norm-c map [ x -> x / (sum capability )] capability
    let mean-capability mean norm-c
    let balance-score sqrt(mean map [a -> (a - mean-capability) ^ 2] norm-c)
    set balance-scores lput balance-score balance-scores
  ]
  print (word "==== Specialization Metrics =====")
  print (word "== BALENCE SCORE (higher means more specialized)")
  print (word "Max: " precision max balance-scores 2)
  print (word "Min: " precision min balance-scores 2)
  print (word "Mean: " precision mean balance-scores 2)
  print (word "Std: " precision standard-deviation balance-scores 2)
end

to compute-specialization-switches

  ask nodes [
    let specialization-switches 0

    ;; Loop through each capability update in cap-updates list
    let previous-capability nobody
    let previous-specialization nobody

    foreach cap-updates [ x ->  ;; x is each capability vector in cap-updates
      let current-capability x

      ;; Specialization Switches: Detect dominant component change
      let current-specialization position max current-capability current-capability
      if previous-specialization != nobody and current-specialization != previous-specialization [
        set specialization-switches specialization-switches + 1
      ]

      ;; Update previous states
      set previous-capability current-capability
      set previous-specialization current-specialization
    ]

    ;; Display results for each node

    print (word "Node " self " - Specialization Switches: " specialization-switches)
  ]
end







@#$#@#$#@
GRAPHICS-WINDOW
1229
20
1666
458
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
800
560
862
605
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
390
665
795
698
number-of-nodes
number-of-nodes
1
100
30.0
1
1
NIL
HORIZONTAL

BUTTON
865
560
928
605
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
390
595
795
628
number-of-tasks
number-of-tasks
0
100
10.0
1
1
NIL
HORIZONTAL

SLIDER
390
560
795
593
alpha
alpha
0
1
0.1
0.1
1
NIL
HORIZONTAL

MONITOR
800
45
1020
90
Tasks unable to complete
tasks-overflowed
17
1
11

PLOT
800
95
1225
335
TASKS LOST
ticks
Tasks
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"LOST 1" 1.0 0 -7500403 true "" "plot item 0 tasks-overflowed"
"LOST 2" 1.0 0 -10899396 true "" "plot item 1 tasks-overflowed"
"LOST 3" 1.0 0 -955883 true "" "plot item 2 tasks-overflowed"
"LOST 4" 1.0 0 -5825686 true "" "plot item 3 tasks-overflowed"
"LOST 5" 1.0 0 -2674135 true "" "plot item 4 tasks-overflowed"

MONITOR
390
45
600
90
Tasks completed
tasks-finished
17
1
11

PLOT
390
95
795
335
TASKS FINISHED
time
amount
0.0
10.0
0.0
10.0
false
true
"set-plot-y-range 0 ((stop-at-ticks * number-of-tasks) / 5)\nset-plot-x-range 0 stop-at-ticks" ""
PENS
"FIN 1" 1.0 0 -7500403 true "" "plot item 0 tasks-finished"
"FIN 2" 1.0 0 -10899396 true "" "plot item 1 tasks-finished"
"FIN 3" 1.0 0 -955883 true "" "plot item 2 tasks-finished"
"FIN 4" 1.0 0 -14835848 true "" "plot item 3 tasks-finished"
"FIN 5" 1.0 0 -11221820 true "" "plot item 4 tasks-finished"

SLIDER
390
630
795
663
stop-at-ticks
stop-at-ticks
100
10000
1000.0
50
1
NIL
HORIZONTAL

PLOT
800
340
1225
555
TTL OF FINISHED TASKS
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"TTL 1" 1.0 0 -7500403 true "" "plot item 0 fin-ttl / item 0 tasks-finished"
"TTL 2" 1.0 0 -2674135 true "" "plot item 1 fin-ttl / item 1 tasks-finished"
"TTL 3" 1.0 0 -955883 true "" "plot item 2 fin-ttl / item 2 tasks-finished"
"TTL 4" 1.0 0 -6459832 true "" "plot item 3 fin-ttl / item 3 tasks-finished"
"TTL 5" 1.0 0 -1184463 true "" "plot item 4 fin-ttl / item 4 tasks-finished"

PLOT
390
340
795
555
avarage task age
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot avg-task-age"

MONITOR
1230
465
1350
510
number of nodes
count nodes
17
1
11

PLOT
1350
465
1665
690
nodes
ticks
number
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count nodes"

BUTTON
1005
560
1137
605
print capabilities
print-node-capabilities\nask nodes [\nifelse working-on = nobody [\n   show(word \"Capabilities \" map [ c -> precision c 2 ] capability \" | Working-on \" working-on \" | Task-stack \" stack-of-tasks \" | Max-capacity \" max-capacity \" | dead-time \" idle-time \" | Neighours \" link-neighbors)\n  ] [\n   show(word \"Capabilities \" map [ c -> precision c 2 ] capability \" | Working-on \" working-on [task-type] of working-on \" | Task-stack \" stack-of-tasks \" | Max-capacity \" max-capacity \" | dead-time \" idle-time \" | Neighours \" link-neighbors)\n  ]\n ]\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
930
560
1002
605
go one
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
390
700
795
733
num_links
num_links
0
10
6.0
1
1
NIL
HORIZONTAL

SLIDER
390
735
795
768
max-idle-time
max-idle-time
1
10
10.0
1
1
NIL
HORIZONTAL

MONITOR
1140
560
1225
605
tasks open
(ticks * number-of-tasks) - sum tasks-overflowed - sum tasks-finished
17
1
11

MONITOR
1230
510
1350
555
nodes fired
fired
17
1
11

MONITOR
605
45
795
90
Total tasks completed
total-tasks-finished
17
1
11

MONITOR
1025
45
1225
90
Total tasks unable to complete
total-tasks-overflowed
17
1
11

PLOT
35
95
385
245
Total number of created nodes each round
ticks
nodes
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot hired"

PLOT
35
250
385
400
Total number of fired nodes each round
ticks
nodes
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot fired"

MONITOR
1230
600
1350
645
Mean node age
mean ages
2
1
11

MONITOR
1230
555
1350
600
mean nodes
round mean num-nodes
0
1
11

BUTTON
800
610
997
655
Print Balence Scores
compute-balence-scores
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1230
645
1350
690
nodes hired
hired
17
1
11

BUTTON
800
660
1025
710
Print number of specializ. switches
compute-specialization-switches
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
1015
615
1127
648
LOGGING
LOGGING
1
1
-1000

@#$#@#$#@
## WHAT IS IT?

This model aims to show that specialisation naturally emerges in organizations. And that
this specialisation of individuals improves the overall performance / effectiveness of the system as a whole.

## HOW IT WORKS

At setup, a small number of seeds (circles) and a large number of turtles are randomly placed in the view. When the go button is clicked, the turtles begin to move. While they move they keep track of the seeds around them, and when they have two or more seeds that are equidistant to them, and are the closest seeds to them, they stop moving. As a result of this behavior, the turtles stop moving along the borders between seed regions, resulting in a Voronoi diagram.

This is one of two voronoi diagram models in the models library, but the two are quite different. In the other model, the voronoi diagram is created by having each patch look to its nearest seed to decide what color to be, which produces the colored polygons. In this model on the other hand, the agents move around trying to locate positions where they do not have a single nearest seed. In other words, they are trying to locate a point that is not part of a polygon at all. In trying to find these locations, the turtles collectively end up defining the boundaries of the polygons in the diagram. The polygons emerge from the lines created by the turtles when they stop moving.

## HOW TO USE IT

Use the NUM-SEEDS slider to choose how many points you want and the NUM-TURTLES slider to determine how many turtles to add to the model, then press SETUP.  The model will place seeds and turtles randomly in the view. When you press the GO button, you will see the turtles start to move around the screen, stopping when they are equidistant from their closest seeds. As more turtles come to rest, a Voronoi diagram emerges.

The GO-MODES chooser lets you define how the turtles will move. The RANDOM mode will have the turtles move based on the random direction they were facing at setup time. The ORGANIZED mode will have each turtle face the seed that it is closest to, then move away from it. In both modes, the turtles follow the same rules for deciding when to stop moving as discussed above in the How It Works section.

Keeping the GO button pressed, you can interact with the model by selecting an option from the MOUSE-ACTIONS chooser, and clicking the DO MOUSE ACTION button. There are four mouse actions defined for the model. The ADD-NEW-SEEDs option allows you to add new seeds to the model. The REMOVE-SEEDS option lets you click on existing seeds to remove them. The MOVE-SEEDS option lets you click and drag seeds around the screen. Finally, the ADD-TURTLES option allows you to add more turtles to the model. As you interact with the model, you will see the polygons redraw based on the changing seed arrangement.

If you unclick the GO button, you can still make changes to the seeds. When you press the GO button again, you will see the turtles begin to move again, creating a new Voronoi diagram based around the changes you have made.

## THINGS TO NOTICE

The lines that are formed by the turtles between the seeds are exactly midway between them.

How many sides do the polygons formed by the turtles typically have?  (You may want to ignore the polygons around the edges.)

What is the difference between the RANDOM and ORGANIZED turtle behaviors? Do the different behaviors result in different diagrams?

Looking at the code tab, the go-random and go-organized procedures control the turtle behavior. Both of these methods are very short, the RANDOM go-mode only has 3 lines! Can you figure out what these 3 lines are doing? Are you surprised that so few lines can produce such a complicated diagram?

## THINGS TO TRY

Experiment with the effect of moving the points around, adding points, and removing points.

The turtles form polygons around the seeds - can you arrange the seeds to make the turtles form a triangle? How about a square? Or an octagon?

What happens if you arrange the seeds in a grid? Or a single straight line?

Does it always take the same amount of time for the turtles to find the boundary between points? Can you arrange the seeds in such a way that it takes the turtles a long time to find a place where they are equidistant from two points?

## EXTENDING THE MODEL

Currently, the seeds and turtles are randomly distributed. By systematically placing the seeds, you can create pattern with the turtles. Add buttons that arrange the seeds in patterns that create specific shapes in the model.

You could imagine systems where there could be different size seeds, and turtles would have a strong or weaker attraction to the seeds based on the seeds size. Implement a model that has variable size seeds and replaces the distance calculation with an attraction calculation based on the seeds size. How does this change the resulting Voronoi diagrams?

## NETLOGO FEATURES

The core procedures for the turtles are go-random and go-organized. The only difference between the two is that in go organized, we added two lines to make the turtles face the closest seed. These procedures use the `min-one-of` and `distance` reporters to find the nearest seed in a very succinct way.

The `mouse-down?`, `mouse-xcor`, and `mouse-ycor` primitives are used so the user can interact with the model.

The go method uses the `run` command to decide which behavior the turtles should follow by reading the go-mode chooser. Similarly, we use the `run` command to decide which mouse action to execute. This command allows one button (the DO MOUSE ACTION button) to produce different behaviors based on the value of the MOUSE-ACTION chooser.

`tick-advance` is used in place of tick to allow the go-mode methods to be executed multiple times per whole tick. This results in the view updating less frequently giving the turtles the appearance of moving faster.

We use the `in-radius` command to figure out if any of the seeds are too close together.

## RELATED MODELS

* Voronoi
* MaterialSim Grain Growth
* Fur
* Honeycomb
* Scatter
* Hotelling's Law

## CREDITS AND REFERENCES

For more information on Voronoi diagrams, see https://en.wikipedia.org/wiki/Voronoi.  (There are also many other sites on this topic on the web.)

This model was inspired by a Processing implementation of a Voronoi diagram, available here: https://www.openprocessing.org/sketch/7571

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Weintrop, D. and Wilensky, U. (2013).  NetLogo Voronoi - Emergent model.  http://ccl.northwestern.edu/netlogo/models/Voronoi-Emergent.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 2013 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

<!-- 2013 Cite: Weintrop, D. -->
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="NO_LINKS | 10 NODES 10 TASKS | STOP 500" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>sum tasks-finished</metric>
    <metric>tasks-completed-difficulty-1</metric>
    <metric>tasks-completed-difficulty-2</metric>
    <metric>tasks-completed-difficulty-3</metric>
    <metric>tasks-completed-difficulty-4</metric>
    <metric>tasks-completed-difficulty-5</metric>
    <enumeratedValueSet variable="number-of-tasks">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-idle-time">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stop-at-ticks">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_links">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="THREE_LINKS | 10 NODES 10 TASKS | STOP 500" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>sum tasks-finished</metric>
    <metric>tasks-completed-difficulty-1</metric>
    <metric>tasks-completed-difficulty-2</metric>
    <metric>tasks-completed-difficulty-3</metric>
    <metric>tasks-completed-difficulty-4</metric>
    <metric>tasks-completed-difficulty-5</metric>
    <enumeratedValueSet variable="number-of-tasks">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-idle-time">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stop-at-ticks">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_links">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="FIVE_LINKS | 10 NODES 10 TASKS | STOP 500" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>sum tasks-finished</metric>
    <metric>tasks-completed-difficulty-1</metric>
    <metric>tasks-completed-difficulty-2</metric>
    <metric>tasks-completed-difficulty-3</metric>
    <metric>tasks-completed-difficulty-4</metric>
    <metric>tasks-completed-difficulty-5</metric>
    <enumeratedValueSet variable="number-of-tasks">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-idle-time">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stop-at-ticks">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_links">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SIX_LINKS | 30 NODES | 10 TASKS | 1000 TICKS" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>sum tasks-finished</metric>
    <metric>tasks-completed-difficulty-1</metric>
    <metric>tasks-completed-difficulty-2</metric>
    <metric>tasks-completed-difficulty-3</metric>
    <metric>tasks-completed-difficulty-4</metric>
    <metric>tasks-completed-difficulty-5</metric>
    <enumeratedValueSet variable="number-of-tasks">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-idle-time">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stop-at-ticks">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_links">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="LOGGING">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
