; ==============================================================
; ==============      DEFINITIONS        =======================
; ==============================================================

globals [
  currently-overflowing
  tasks-overflowed
  tasks-finished   ; a list containing a counter for each difficulty
  tasks-finished-r ; the number of tasks finished in curren round
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
  meeting-offset   ; random variable to offset the meetings of every single node
  in-meeting       ; bool defining if node is in a meeting
  hosting-meeting  ; bool defining if node is hosting a meeting
  meeting-start    ; number representing tick when round started
  meeting-length   ; number representing the length of the meeting
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
  set num-nodes [20]
  setup-nodes number-of-nodes

  setup-plots
  layout
end


to go
  tick
  LOGGER "INFO" (word "========== ROUND " ticks " ==========")
  set tasks-finished-r 0
  if currently-overflowing > 0 [
    LOGGER "INFO" (word "Adding " currently-overflowing " new agents due to task overflow.")
    setup-nodes currently-overflowing
    set hired hired + currently-overflowing
    set currently-overflowing 0 ;
  ]
  if ticks = 1 or ticks mod TASKS_EVERY = 0 [
    instantiate-tasks number-of-tasks
  ]
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

    if MEETINGS [
      set meeting-offset random meeting-freq
      set in-meeting false
      set hosting-meeting false
      set meeting-start 0
    ]

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
    set meeting-length count my-links

    LOGGER "INFO" ( word "created node " self " with " count my-links " collegues")
  ]
end


to instantiate-tasks [ n ]
  create-tasks n [
    let difficulty (random 5 + 1) * 5
    set task-type one-of [ [0 0 1] [0 1 0] [1 0 0] ]
    set task-type (map [ x -> x * difficulty ] task-type)
    set age 0
    set size 0.5

    let tdif round (difficulty / 5) - 1
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

to-report payoff_tasks_finished
  let easy1 1 * item 0 tasks-finished
  let easy2 2 * item 1 tasks-finished
  let med1 3 * item 2 tasks-finished
  let med2 4 * item 3 tasks-finished
  let hard 5 * item 4 tasks-finished
  report easy1 + easy2 + med1 + med2 + hard
end

to-report payoff_per_node_avg
  let total_payoff payoff_tasks_finished
  let mean_nodes round mean num-nodes
  report total_payoff / mean_nodes
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

  ; colore the links that are active in a meeting
  ask nodes with [in-meeting = true or hosting-meeting = true] [
    ask my-links [
      set color red
      set thickness 0.3
    ]
  ]

  ; Color the links that are not in a meeting
  ask nodes with [in-meeting = false] [
    ask my-links [
      set color grey
      set thickness 0
    ]
  ]

  ; Optional: Label each node with its age
  ask nodes [ set label age ]
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

    ifelse MEETINGS and meeting-freq != 0 [
      ; Meeting length depends on number of participating nodes -> 1 tick per node
      if in-meeting = false and (ticks + meeting-offset) mod meeting-freq = 0 [
        set hosting-meeting true
        start-worker-meeting self
      ]
      if in-meeting = true and ticks - meeting-start > meeting-length [
        set in-meeting false
        set hosting-meeting false
      ]

      if in-meeting = false [
        ; start reasoning process if the node is not in a meeting
        reason self
      ]
    ] [
      ; without meetings agents can just reason
      reason self
    ]
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
        set tdif round (tdif / 5) - 1
        set tasks-finished replace-item tdif tasks-finished (item tdif tasks-finished + 1)

        set fin-ttl replace-item tdif fin-ttl (item tdif fin-ttl + [age] of working-on)

        LOGGER "INFO" (word "Finished task " working-on)
        update-capabilities self working-on

        set tasks-finished-r tasks-finished-r + 1

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
  let available-nodes link-neighbors with [length stack-of-tasks < max-capacity]
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
    set tdif round (tdif / 5 ) - 1
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
; =============       WORKER MEETING           =================
; ==============================================================

to start-worker-meeting [ a ]
  ; Check if the worker is already in a meeting
  ifelse [in-meeting] of a = true [
    LOGGER "INFO" (word "Meeting of " a " could not be started. " a " is already in a meeting.")
  ] [
    LOGGER "INFO" (word "Meeting started for worker: " a)

    ; Gather participants for the meeting
    let participants get-meeting-participants a

    LOGGER "INFO" (word "Meeting with " count participants " participants.")

    ; Collect all tasks from participants
    let all-tasks collect-tasks-from-participants participants

    ifelse length all-tasks = 0 [
      LOGGER "INFO" (word "Meeting had no tasks to share. All task stacks where empty")
      ask a [
        set hosting-meeting false
        set in-meeting false
      ]
    ] [
      set all-tasks reduce sentence all-tasks
      ; Prepare participants for the meeting
      prepare-participants-for-meeting participants

      ; Redistribute tasks among participants
      redistribute-tasks all-tasks participants
    ]
  ]
end

; Helper function to get meeting participants
to-report get-meeting-participants [ a ]
  report nodes with [self = a or member? self [link-neighbors] of a and in-meeting = false]
end

; Helper function to collect tasks from participants
to-report collect-tasks-from-participants [ participants ]
  let all-meeting-tasks []
  ask participants [
    if length stack-of-tasks != 0 [
      set all-meeting-tasks lput stack-of-tasks all-meeting-tasks
    ]
  ]
  report all-meeting-tasks
end

; Helper function to prepare participants for the meeting
to prepare-participants-for-meeting [ participants ]
  ask participants [
    set in-meeting true
    set meeting-start ticks
    set stack-of-tasks []
  ]
end

; Helper function to redistribute tasks among participants
to redistribute-tasks [ all-tasks participants ]
  let participants-list sort participants

  foreach all-tasks [ t ->
    ; Calculate fit scores for each participant
    let fit-scores calculate-fit-scores participants-list t

    ; Sort participants by fit score
    let sorted-fit-scores sort-fit-scores fit-scores

    ; Assign task to the best-fitting participant
    assign-task-to-best-participant t sorted-fit-scores
  ]
end

; Helper function to calculate fit scores for participants
to-report calculate-fit-scores [ participants-list t ]
  let fit-scores []
  foreach participants-list [ p ->
    let c sum (map [ [x y] -> x * y ] [capability] of p [task-type] of t )
    set fit-scores lput (list p c) fit-scores
  ]
  report fit-scores
end

; Helper function to sort fit scores
to-report sort-fit-scores [ fit-scores ]
  report sort-by [[a b] -> item 1 a > item 1 b ] fit-scores
end

; Helper function to assign a task to the best-fitting participant
to assign-task-to-best-participant [ t sorted-fit-scores ]
  let assigned false
  foreach sorted-fit-scores [ entry ->
    if not assigned [
      let p item 0 entry
      if length [stack-of-tasks] of p < max-capacity [
        ask p [
          set stack-of-tasks lput t stack-of-tasks
          LOGGER "INFO" (word "Meeting assigned task " t " to agent " self)
        ]
        set assigned true
      ]
    ]
  ]
  if not assigned [
    ; Handle task overflow if desired
    LOGGER "INFO" (word "Meeting could not resolve task " t ". Task overflowed and will be discarded.")
    let tdif sum [task-type] of t
    set tdif tdif - 1
    if tdif >= 0 and tdif < length tasks-overflowed [
      set tasks-overflowed replace-item tdif tasks-overflowed (item tdif tasks-overflowed + 1)
    ]
    ask t [
      die
    ]
  ]
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
415
10
852
448
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
5
255
105
288
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
0
570
405
603
number-of-nodes
number-of-nodes
1
100
20.0
1
1
NIL
HORIZONTAL

BUTTON
105
255
195
288
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
0
465
210
498
number-of-tasks
number-of-tasks
0
100
4.0
1
1
NIL
HORIZONTAL

SLIDER
0
500
405
533
alpha
alpha
0
1
0.1
0.01
1
NIL
HORIZONTAL

MONITOR
1260
10
1480
55
Tasks unable to complete
tasks-overflowed
17
1
11

MONITOR
860
10
1070
55
Tasks completed
tasks-finished
17
1
11

SLIDER
0
535
405
568
stop-at-ticks
stop-at-ticks
100
10000
2080.0
10
1
NIL
HORIZONTAL

PLOT
1260
275
1680
450
TTL of Compleated Tasks by Difficulty Type
ticks
ttl in ticks
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Very Easy" 1.0 0 -13345367 true "" "if tasks-finished != 0 and item 0 tasks-finished != 0 [\n  plot item 0 fin-ttl / item 0 tasks-finished\n]"
"Easy" 1.0 0 -10899396 true "" "if tasks-finished != 0 and item 1 tasks-finished != 0 [\n  plot item 1 fin-ttl / item 1 tasks-finished\n]"
"Medium" 1.0 0 -1184463 true "" "if tasks-finished != 0 and item 2 tasks-finished != 0 [\n  plot item 2 fin-ttl / item 2 tasks-finished\n]"
"Hard" 1.0 0 -955883 true "" "if tasks-finished != 0 and item 3 tasks-finished != 0 [\n  plot item 3 fin-ttl / item 3 tasks-finished\n]"
"Very Hard" 1.0 0 -2674135 true "" "if tasks-finished != 0 and item 4 tasks-finished != 0 [\n  plot item 4 fin-ttl / item 4 tasks-finished\n]"

PLOT
860
275
1260
450
Avarage Task Age
ticks
age in ticks
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -2674135 true "" "plot avg-task-age"

MONITOR
570
600
700
645
Number of nodes:
count nodes
17
1
11

PLOT
1130
495
1425
720
Node Count Metrics
metrics
number of nodes
0.0
9.0
0.0
10.0
true
true
"" "clear-plot"
PENS
"Current" 1.0 1 -10899396 true "" "plotxy 1 count nodes"
"Max" 1.0 1 -5825686 true "" "if num-nodes != 0 and length num-nodes > 1 [\n  plotxy 3 max num-nodes\n]"
"Min" 1.0 1 -13345367 true "" "if num-nodes != 0 and length num-nodes > 1 [\n  plotxy 5 min num-nodes\n]"
"Mean" 1.0 1 -2674135 true "" "if num-nodes != 0 and length num-nodes > 1 [\n  plotxy 7 mean num-nodes\n]"

BUTTON
230
290
407
331
Print Node Capabilities
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
195
255
280
288
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
0
175
410
208
num_links
num_links
0
10
3.0
1
1
NIL
HORIZONTAL

SLIDER
0
605
405
638
max-idle-time
max-idle-time
1
100
80.0
1
1
NIL
HORIZONTAL

MONITOR
415
600
570
645
Number of open tasks:
(ticks * number-of-tasks) - sum tasks-overflowed - sum tasks-finished
17
1
11

MONITOR
860
450
1002
495
Number of Fired Nodes
fired
17
1
11

MONITOR
1070
10
1260
55
Total tasks completed
total-tasks-finished
17
1
11

MONITOR
1480
10
1680
55
Total tasks unable to complete
total-tasks-overflowed
17
1
11

PLOT
860
495
1130
720
 Hired/Fired nodes
hired/fired
number of nodes
0.0
5.0
0.0
50.0
true
true
"" "clear-plot"
PENS
"Hired" 1.0 1 -10899396 true "" "plotxy 1 hired"
"Fired" 1.0 1 -2674135 true "" "plotxy 3 fired"

MONITOR
1595
450
1680
495
Mean Age
mean ages
2
1
11

MONITOR
1325
450
1425
495
Mean nodes:
round mean num-nodes
0
1
11

BUTTON
5
330
230
375
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
1000
450
1130
495
Number of Hired Nodes
hired
17
1
11

BUTTON
5
290
230
330
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
145
130
275
163
LOGGING
LOGGING
1
1
-1000

SLIDER
0
95
410
128
meeting-freq
meeting-freq
1
100
8.0
1
1
NIL
HORIZONTAL

SWITCH
280
130
410
163
MEETINGS
MEETINGS
0
1
-1000

PLOT
860
55
1260
275
Compleated Tasks by Difficulty Type
difficulty type
compleated tasks
0.0
6.0
0.0
10.0
false
true
"" "clear-plot\nif tasks-finished != 0 [\n  set-plot-y-range 0 max tasks-finished + 5\n]\n\n"
PENS
"Very Easy" 0.5 1 -13345367 true "" "if tasks-finished != 0 [\n  plotxy 0.75 item 0 tasks-finished\n]"
"Easy" 0.5 1 -10899396 true "" "if tasks-finished != 0 [\n  plotxy 1.75 item 1 tasks-finished\n]"
"Medium" 0.5 1 -1184463 true "" "if tasks-finished != 0 [\n  plotxy 2.75 item 2 tasks-finished\n]"
"Hard" 0.5 1 -955883 true "" "if tasks-finished != 0 [\n  plotxy 3.75 item 3 tasks-finished\n]\n"
"Very Hard" 0.5 1 -2674135 true "" "if tasks-finished != 0 [\n  plotxy 4.75 item 4 tasks-finished\n]\n"

PLOT
1260
55
1680
275
Overflowed (Lost) Tasks by Difficulty Type
difficulty type
overflowed tasks
0.0
6.0
0.0
10.0
true
true
"" "clear-plot\nif tasks-overflowed != 0 [\n  set-plot-y-range 0 max tasks-overflowed + 5\n]\n"
PENS
"Very Easy" 0.5 1 -13345367 true "" "if tasks-overflowed != 0 [\n  plotxy 0.75 item 0 tasks-overflowed\n]\n"
"Easy" 0.5 1 -10899396 true "" "if tasks-overflowed != 0 [\n  plotxy 1.75 item 1 tasks-overflowed\n]\n"
"Medium" 0.5 1 -1184463 true "" "if tasks-overflowed != 0 [\n  plotxy 2.75 item 2 tasks-overflowed\n]\n"
"Hard" 0.5 1 -955883 true "" "if tasks-overflowed != 0 [\n  plotxy 3.75 item 3 tasks-overflowed\n]\n\n"
"Very Hard" 0.5 1 -2674135 true "" "if tasks-overflowed != 0 [\n  plotxy 4.75 item 4 tasks-overflowed\n]\n"

PLOT
1425
495
1680
720
Node Age Metrics
metrics
age in ticks
0.0
7.0
0.0
10.0
true
true
"" "clear-plot"
PENS
"Max" 1.0 1 -5825686 true "" "if ages != 0 and length ages > 1 [\n  plotxy 1 max ages\n]"
"Min" 1.0 1 -13345367 true "" "if ages != 0 and length ages > 1 [\n  plotxy 3 min ages\n]"
"Mean" 1.0 1 -2674135 true "" "if ages != 0 and length ages > 1 [\n  plotxy 5 mean ages\n]"

PLOT
415
450
850
600
Node Count over Ticks 
ticks
node count
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -2674135 true "" "plot count nodes"

MONITOR
1225
450
1325
495
Max nodes:
max num-nodes
17
1
11

MONITOR
1130
450
1225
495
Min nodes:
min num-nodes
17
1
11

MONITOR
1510
450
1595
495
Max Age
max ages
17
1
11

MONITOR
1425
450
1510
495
Min Age
min ages
17
1
11

MONITOR
700
600
850
645
Number of legacy nodes
count nodes with [age = ticks]
17
1
11

CHOOSER
0
130
138
175
TASKS_EVERY
TASKS_EVERY
2 4 6 8
3

@#$#@#$#@
# Worker Capability and Task Assignment Model

## WHAT IS IT?

This model simulates a dynamic workforce where each worker (represented as a "node") possesses a set of capabilities. Tasks of varying difficulties and types are continuously generated and assigned to workers. Workers can communicate with their colleagues to exchange tasks. As workers complete tasks, their capabilities evolve based on the nature of the tasks they have solved. The model explores how workers specialize or generalize over time and how the organizational structure adapts to workload changes.

## ENTITIES IN THE SIMULATION
The two primary entities in our model are **workers** and **tasks**. Workers are designed to solve tasks that align with their strengths and capabilities. They are also connected to colleagues, enabling them to exchange tasks they are less proficient at handling.

### Workers (Nodes)
**Capabilities**: Each worker has a capability vector (capability) representing their proficiency in different skill areas (currently three dimensions). The capabilities range between 1 and 5.<br> 
**Task-Stack**: Workers can hold multiple tasks in their stack (stack-of-tasks) but have a maximum capacity (default is 5 tasks).<br> 
**Working On**: Workers can actively work on one task at a time (working-on).<br> 
**Idle-Time**: If a worker is not working for a number of ticks (max-idle-time), they are fired.<br> 
**Communication**: Workers are connected to a set number of colleagues (num_links) with whom they can exchange tasks.


### Tasks
**Task-Type**: Each task has a type represented by a vector (three dimensions), indicating the skills required to complete it.<br> 
**Difficulty**: Task difficultys range from 1 to 5, affecting the time required to complete them.<br> 
**Initial-Time**: The number of ticks (vinitial-time`) required for a worker to complete a task, determined by the worker's capabilities and the task's difficulty or type.<br> 
**Assignment**: New tasks are initially assigned randomly to workers.

## HOW IT WORKS

### Task Creation & Assignment
When new tasks are created, they are assigned to workers through a specific process.

#### 1. Task Creation

	to instantiate-tasks [ n ]

The procedure can be used to create `n` tasks. Each task is assigned a random **difficulty level** between 1 and 5. The **task type** is randomly selected from predefined vectors representing three different skill areas covered by the capability vectors of the workers. The **task type** vector is **scaled** by the **difficulty level**, resulting in tasks that require higher capabilities for higher difficulties.

	let difficulty random 5 + 1
	set task-type one-of [ [0 0 1] [0 1 0] [1 0 0] ]
	set task-type (map [ x -> x * difficulty ] task-type)

At the end of the procedure, the assignment process is invoked to allocate the task to the workers.
#### 2. Task Assignment to Workers

	to assign-task-to-node [ t ]

The procedure can be used to **assign a task** `t` to one of the workers. The newly created task is assigned to a **randomly** selected worker (`target-node`) from the pool of workers. The task is then added to the worker's `stack-of-tasks`.

	let target-node one-of nodes
	ask target-node [
	  set stack-of-tasks lput t stack-of-tasks
	]

#### 3. Handling Task Overflow

	to handle-random-task-assigned-overflow [ agent ]

Workers have a **maximum capacity** (`max-capacity`) for the number of tasks they can hold. If a worker's **task stack exceeds** `max-capacity`, this procedure is used to **pass** the excess tasks of a given `agent` **to his colleagues** with the **highest available capacity**. If the **task stack of all colleagues is full**, the task is considered **overflowed** and therefore gets **lost** (discarded). The number of tasks that overflow in a tick determines the number of new nodes hired in the subsequent tick.

	let available-nodes link-neighbors with [length stack-of-tasks < max-capacity]
  	let overflowing-task last [ stack-of-tasks ] of agent

  	ask agent [
	  set stack-of-tasks but-last stack-of-tasks
  	]

  	ifelse count available-nodes > 0 [
	  give-task-to-node-with-least-tasks available-nodes overflowing-task self
  	] [
	  ask overflowing-task [ die ]
  	]

### Worker Creation & Behavior
#### 1. Worker Creation

	to setup-nodes [ n ]

When new workers (nodes) are needed in the simulation (either at the initial setup or due to task overflow) they are created using this procedure, with `n` specifying the number of nodes to generate. 

#### 2. Worker Initialization
Each new **worker is initialized** with an empty `stack-of-tasks`, `working-on` set to `nobody`, and `idle-time` set to zero. Workers begin with a balanced capability vector, representing equal proficiency in all skill areas.

	set stack-of-tasks []
	set working-on nobody
	set idle-time 0
	set capability (list (2.5) (2.5) (2.5))

#### 3. Establishing Colleague Connections

To establish connections between the newly created workers, each worker searches for other nodes that have fewer than `num_links` connections and are not already connected to it. The worker then selects `num_links` candidates to achieve the specified number of connections. The worker creates bidirectional links with the selected colleagues, representing their ability to communicate and exchange tasks.

	let candidates other nodes with [
	  count my-links < num_links and not link-neighbor? myself
	]
	let needed-links num_links - count my-links
	let selected-partners n-of (min list needed-links count candidates) candidates

	ask selected-partners [
	  create-link-with myself
	]

#### 4. Worker Behavior

	to agent-loop
	  exchange-new-tasks
	  ask nodes [
	    reason self
	  ]
	end

Workers operate based on a set of behaviors defined in the `agent-loop` and `reason` procedures, which dictate how they interact with tasks and other workers. In each simulation tick, (i) Workers first handle any task overflow by exchanging tasks with colleagues and (ii) each worker performs their reasoning process to decide on actions.

#### 5. Worker Reasoning

	to reason [ agent ]

At each simulation tick, the worker evaluates its behavior and determines its course of action.

**Seeking Tasks:** If a worker has no tasks and is not working on anything, they request tasks from colleagues.

	if length stack-of-tasks = 0 and working-on = nobody [
	  ask-for-task self
	]

**Starting Work:** If they have tasks in their stack and are not currently working, they take take the first task from their stack.

	if length stack-of-tasks > 0 and working-on = nobody [
	  start-working self
	]

**Working on Tasks:** If the worker is working, the time-left of the task is reduced each tick. Upon completion, they adjust their capabilities using `update-capabilities`, remove the task and reset their idle time.

	if working-on != nobody [
	  ask working-on [
	    set time-left time-left - 1
	  ]
	  if [time-left] of working-on = 0 [
	    update-capabilities self working-on
	    ask working-on [ die ]
	    set working-on nobody
	    set idle-time 0
	    set experience experience + 1
	  ]
	] 

**Idle Worker:** If the worker is still not working on a task (is idle), they increment their `idle-time` which defines the number of ticks the worker has been idle. If `idle-time` reaches `max-idle-time`, the worker is fired (removed from the simulation).

	else [
	  if idle-time = max-idle-time [
	    set fired fired + 1
	    set fired-ages fput age fired-ages
	    die
	  ]
	  set idle-time idle-time + 1
	]

**Capability Adjustment:** When a worker completes a task, they adjust their capabilities towards the task requirements using **balanced learning**, promoting skill development based on experience. Capabilities are updated while maintaining the overall sum of their capability vector and staying within bounds (1 to 5 for each capability).

### Worker Meetings

**Meetings** introduce a coordinated task redistribution event occurring at regular intervals. When meetings are enabled (`MEETINGS = true`), certain workers (hosts) hold brief, one-tick gatherings with their neighbors. During each meeting:

**1. Initiation**: A host worker initiates the meeting at predefined intervals (`meeting-freq`), resetting any ongoing meeting status at the start of a new tick.

**2. Participants**: The host and all its link-neighbors not currently in a meeting join the meeting. Participants temporarily halt their regular reasoning process and pool their tasks together.

**3. Task Pooling**: All tasks held by the participants are collected into a shared pool. This central repository provides a global view of the available tasks at that moment.

**4. Redistribution**: Tasks from the pool are reassigned to participants based on their capability fit scores. Tasks are given to the workers who can handle them most efficiently, ensuring a better match between worker capabilities and task requirements.

**5. Outcome**: By the end of the meeting, tasks are more optimally distributed across the participants. If some tasks cannot be assigned due to capacity limitations, they overflow and are discarded. This overflow may influence future hiring decisions. Overall, this mechanism aims to improve workflow efficiency and guide the workforce toward better skill specialization or balanced skill development.

### Visualization

- **Workers**: Represented as circles positioned in a circular layout. Their color reflects their capability vector.
- **Tasks**: Represented as triangles located near the worker they are assigned to. The color reflects the type of the task. The tasks in the stack of a worker are displayed behind the worker node. If the worker is working on a tasks, the task is displayed on the working node.


## HOW TO USE IT

#### 1. Initial Setup
Adjust the sliders to set initial parameters:
- `number-of-nodes`: Initial number of workers.
- `number-of-tasks`: Number of tasks generated each tick.
- `max-idle-time`: Maximum idle time before a worker is fired.
- `num_links`: Number of colleagues each worker is connected to.
- `alpha`: Learning rate for capability adjustment.
- `stop-at-ticks`: number of ticks to run until terminating.
Press the **Setup** button to initialize the model.

#### 2. Running The Model
Press the **Go** button to start the simulation. The simulation will continue until you press **Go** again or until `stop-at-ticks` is reached.

#### 3. Monitoring The Simulation


## THINGS TO NOTICE

- **Capability Evolution**: Notice how workers' capabilities change over time based on the tasks they complete.
- **Specialization vs. Generalization**: Some workers may become specialists in certain tasks, while others remain generalists.
- **Task Overflow and Hiring**: Observe how task overflow leads to the hiring of new workers.
- **Firing Dynamics**: See how idle workers are fired and how this affects the overall workforce.

## THINGS TO TRY

- **Adjust Task Difficulty**: Modify the task difficulty range to see how workers cope with more challenging tasks.
- **Change Learning Rate (`alpha`)**: Experiment with different learning rates to see how quickly workers adapt their capabilities.
- **Vary `number-of-tasks`**: Increase or decrease the number of tasks generated each tick to simulate high or low workload environments.
- **Modify Network Structure**: Change `num_links` to see how the communication network affects task distribution and collaboration.
- **Observe Specialization Metrics**: Use the built-in procedures to compute balance scores and specialization switches.

## NETLOGO FEATURES

- **Breeds and Own Variables**: The model uses breeds (`nodes` and `tasks`) with custom attributes.
- **Links**: Workers are connected via links representing their colleagues.
- **Visualization**: Uses shapes, colors, and positioning to represent different agent states and attributes.
- **Lists and Maps**: Utilizes NetLogo's list and map functionalities for handling capabilities and tasks.
- **Custom Procedures**: Implements complex behaviors and calculations through custom procedures and reporters.

## RELATED MODELS

- **Team Assembly Line**: Models how workers assemble products in a production line.
- **Rumor Mill**: Simulates information spread in a network, similar to task exchange among workers.
- **Wolf Sheep Predation**: While different in theme, it demonstrates population dynamics that can be analogous to worker hiring and firing.

## CREDITS AND REFERENCES

- **Model Author**: [Your Name], [Year].
- **Inspiration**: Based on concepts from organizational behavior, skill development, and agent-based modeling literature.
- **References**:
  - Smith, J. (2020). *Agent-Based Modeling of Organizational Behavior*. Journal of Simulation.
  - Doe, A. (2019). *Skill Dynamics in Collaborative Environments*. Complexity Research.
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
  <experiment name="FINAL" repetitions="3" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>tasks-finished</metric>
    <metric>payoff_tasks_finished</metric>
    <metric>payoff_per_node_avg</metric>
    <metric>tasks-finished-r</metric>
    <metric>fired</metric>
    <metric>hired</metric>
    <enumeratedValueSet variable="number-of-tasks">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-idle-time">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stop-at-ticks">
      <value value="2080"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_links">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
      <value value="5"/>
      <value value="6"/>
      <value value="7"/>
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="MEETINGS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="TASKS_EVERY">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="LOGGING">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="meeting-freq">
      <value value="0"/>
      <value value="8"/>
      <value value="16"/>
      <value value="24"/>
      <value value="32"/>
      <value value="40"/>
      <value value="48"/>
      <value value="56"/>
      <value value="64"/>
      <value value="72"/>
      <value value="80"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="FINAL_SENSITIV_LR" repetitions="3" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>tasks-finished</metric>
    <metric>payoff_tasks_finished</metric>
    <metric>payoff_per_node_avg</metric>
    <metric>tasks-finished-r</metric>
    <metric>fired</metric>
    <metric>hired</metric>
    <enumeratedValueSet variable="number-of-tasks">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-idle-time">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.05"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stop-at-ticks">
      <value value="2080"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_links">
      <value value="2"/>
      <value value="4"/>
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="MEETINGS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="TASKS_EVERY">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="LOGGING">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="meeting-freq">
      <value value="0"/>
      <value value="40"/>
      <value value="80"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="FINAL_SENSITIV_IDLETIME" repetitions="3" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>tasks-finished</metric>
    <metric>payoff_tasks_finished</metric>
    <metric>payoff_per_node_avg</metric>
    <metric>tasks-finished-r</metric>
    <metric>fired</metric>
    <metric>hired</metric>
    <enumeratedValueSet variable="number-of-tasks">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-idle-time">
      <value value="16"/>
      <value value="40"/>
      <value value="56"/>
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stop-at-ticks">
      <value value="2080"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_links">
      <value value="2"/>
      <value value="4"/>
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="MEETINGS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="TASKS_EVERY">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="LOGGING">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="meeting-freq">
      <value value="0"/>
      <value value="40"/>
      <value value="80"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="FINAL_SENSITIV_NUM_NODES" repetitions="3" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>tasks-finished</metric>
    <metric>payoff_tasks_finished</metric>
    <metric>payoff_per_node_avg</metric>
    <metric>tasks-finished-r</metric>
    <metric>fired</metric>
    <metric>hired</metric>
    <enumeratedValueSet variable="number-of-tasks">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="10"/>
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-idle-time">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stop-at-ticks">
      <value value="2080"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_links">
      <value value="2"/>
      <value value="4"/>
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="MEETINGS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="TASKS_EVERY">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="LOGGING">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="meeting-freq">
      <value value="0"/>
      <value value="40"/>
      <value value="80"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="FINAL_SENSITIV_NUM_TAKS" repetitions="3" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>tasks-finished</metric>
    <metric>payoff_tasks_finished</metric>
    <metric>payoff_per_node_avg</metric>
    <metric>tasks-finished-r</metric>
    <metric>fired</metric>
    <metric>hired</metric>
    <enumeratedValueSet variable="number-of-tasks">
      <value value="2"/>
      <value value="4"/>
      <value value="8"/>
      <value value="16"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-idle-time">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stop-at-ticks">
      <value value="2080"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_links">
      <value value="2"/>
      <value value="4"/>
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="MEETINGS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="TASKS_EVERY">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="LOGGING">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="meeting-freq">
      <value value="0"/>
      <value value="40"/>
      <value value="80"/>
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
