(use sh)
(import json)
(use time)
(use judge)
(use joy)

(defn keyword-keys [m]
  "Make all keys in a map keywords"
  (var result @{})
  (loop [[key value] :pairs m]
    (set (result (keyword key)) value))
  result)

(defn get-today []
  (let [output ($< task "(scheduled.before:eod or due.before:tom+48h)" export ready)
        json (json/decode output)]
    (map keyword-keys json)))

(defn search [s &opt project]
  (default project "")
  (let [project-search (if (= "" project) ""
                         (string "pro:" project))
        output ($< task status:pending rc.context=none ,s ,project-search export)
        json (json/decode output)]
    (map keyword-keys json)))

(comment
  (search "pro:arch test"))

(defn sync []
  ($ task rc.confirmation=off sync))

(defn get-inbox []
  (let [output ($< task status:pending rc.context=none pro: export)
        json (json/decode output)]
    (map keyword-keys json)))

(defn get-done-today []
  (let [output ($< task status:completed rc.context=none end.after:tod export)
        json (json/decode output)]
    (map keyword-keys json)))

(defn get-item [uuid]
  (let [[success output] (protect ($< task ,uuid export))]
    (if (not success) (error (string "no item found: " output))
      (let [json (json/decode output)
            list (map keyword-keys json)]
        (if (empty? list) (error "no item found")
          (get list 0))))))

(defn modify-custom-string [uuid modify-string]
  ($ task ,uuid mod ,modify-string))

(defn modify [uuid scheduled due project]
  (modify-custom-string uuid (string "scheduled:" scheduled))
  (modify-custom-string uuid (string "due:" due))
  (modify-custom-string uuid (string "project:" project)))

(defn add [description]
  (default description "")
  (if (= "" description) (error "no description given")
    ($ task rc.context=none add ,description)))

(defn complete [uuid]
  ($ task done ,uuid))

(defn delete [uuid]
  ($ task rc.confirmation=off rm ,uuid))

(defn add-missing-days [today-day items]
  (assert (number? today-day) "expected today-day to be a number")
  (assert (>= 7 (length items)) (string "expected items to be equal or less than 7 days, got: " (length items) " days"))
  (let [days (->> (map |(get (get $ 0) :day) items)
                  (filter |(not (nil? $))))
        missing-days (->> (range today-day (- today-day 7) -1)
                          (filter |(not (contains? $ days)))
                          (map (fn [x] @[{:day x}])))
        res (array/concat items missing-days)]
    (assert (= 7 (length res)) (string "expected 7 days, got " (length res) " days"))
    res))

(defn get-notify-items []
  "Get all items that have notifcations over time"
  (let [output ($< task status.not:completed status.not:deleted rc.context=none notify.before:now export)
        json (json/decode output)]
    (map keyword-keys json)))

(defn remove-notify-tag [uuid]
  "Remove notify from item"
  (assert (string? uuid) "expected uuid as string")
  (modify-custom-string uuid "notify:"))

(comment
  (let [uid (-> (get-notify-items)
                (get 0)
                (get :uuid))]))

(defn add-day-from-end [i]
  """
  Add :day that is amount of days since today
  """
  (assert (string? (get i :end)) "expected :end as string in item")
  (as-> (get i :end) _
        (time/parse "%Y%m%dT%H%M%S%z" _ "EUROPE/OSLO")
        (os/date _ :local)
        (get _ :year-day)
        (merge {:day _} i)))

(defn valid-day? [i today-day]
  """
  Check if :day is within 7 days

  Still broken at year boundaries...
  """
  (assert (number? today-day) "expected today-day to be a number")
  (let [day (get i :day)]
    (and (>= today-day day)
         (> 7 (- today-day day)))))

(test (valid-day? @{:day 70} 70) true)
(test (valid-day? @{:day 75} 70) false)
(test (valid-day? @{:day 65} 70) true)
(test (valid-day? @{:day 60} 70) false)
(test (valid-day? @{:day 63} 70) false)
(test (valid-day? @{:day 88} 94) true)


# Broken at year boundaries
(defn group-by-days [items &opt today-day]
  """
  Expects items with :day
  """
  (default today-day (-> (os/date (os/time) :local)
                         (get :year-day)))
  (as-> (filter |(valid-day? $ today-day) items) _
        (sorted-by |(get $ :day) _)
        (partition-by |(get $ :day) _)
        (add-missing-days today-day _)
        (sorted-by |(-> (get $ 0)
                        (get :day)) _)))


(test
  (let [today-day 70]
    (protect (group-by-days @[{:day (- today-day 1) :name "org"}
                              {:day (- today-day 2) :name "another org"}
                              {:day (- today-day 2) :name "org"}
                              {:day (- today-day 6) :name "org"}] today-day)))
  [true
   @[@[{:day 64 :name "org"}]
     @[{:day 65}]
     @[{:day 66}]
     @[{:day 67}]
     @[{:day 68 :name "org"}
       {:day 68 :name "another org"}]
     @[{:day 69 :name "org"}]
     @[{:day 70}]]])

(test # All days are present in input
  (let [today-day 70]
    (protect (group-by-days @[{:day (- today-day 0) :name "org"}
                              {:day (- today-day 1) :name "another org"}
                              {:day (- today-day 2) :name "another org"}
                              {:day (- today-day 3) :name "org"}
                              {:day (- today-day 4) :name "org"}
                              {:day (- today-day 5) :name "org"}
                              {:day (- today-day 6) :name "org"}] today-day)))
  [true
   @[@[{:day 64 :name "org"}]
     @[{:day 65 :name "org"}]
     @[{:day 66 :name "org"}]
     @[{:day 67 :name "org"}]
     @[{:day 68 :name "another org"}]
     @[{:day 69 :name "another org"}]
     @[{:day 70 :name "org"}]]])

(test # Gets more than 7 days as input: should disregard the days/items that are too old
  (let [today-day 77]
    (protect (group-by-days @[{:day (- today-day 0) :name "org"}
                              {:day (- today-day 1) :name "another org"}
                              {:day (- today-day 2) :name "another org"}
                              {:day (- today-day 5) :name "org"}
                              {:day (- today-day 7) :name "org"}
                              {:day (- today-day 10) :name "org"} # too old
                              {:day (- today-day 5) :name "org"}
                              {:day (- today-day 6) :name "org"}] today-day)))
  [true
   @[@[{:day 71 :name "org"}]
     @[{:day 72 :name "org"}
       {:day 72 :name "org"}]
     @[{:day 73}]
     @[{:day 74}]
     @[{:day 75 :name "another org"}]
     @[{:day 76 :name "another org"}]
     @[{:day 77 :name "org"}]]])

(test # Gets 7 days but not in order
  (let [today-day 77]
    (protect (group-by-days @[{:day (- today-day 0) :name "org"}
                              {:day (- today-day 1) :name "another org"}
                              {:day (- today-day 2) :name "another org"}
                              {:day (- today-day 1) :name "org"}
                              {:day (- today-day 3) :name "org"}
                              {:day (- today-day 0) :name "org"}
                              {:day (- today-day 5) :name "org"}
                              {:day (- today-day 6) :name "org"}
                              {:day (- today-day 6) :name "org"}] today-day)))
  [true
   @[@[{:day 71 :name "org"}
       {:day 71 :name "org"}]
     @[{:day 72 :name "org"}]
     @[{:day 73}]
     @[{:day 74 :name "org"}]
     @[{:day 75 :name "another org"}]
     @[{:day 76 :name "another org"}
       {:day 76 :name "org"}]
     @[{:day 77 :name "org"}
       {:day 77 :name "org"}]]])


(defn get-last-seven-days []
  (let [res (->> ($< task end.after:-7d status:completed rc.context=none export)
                 (json/decode)
                 (map keyword-keys)
                 (map add-day-from-end)
                 (group-by-days))]
    (assert (= 7 (length res)) (string "expected 7 days, got " (length res) " days"))
    res))

(comment
  # Should always have a length of 7 days...
  (get-last-seven-days)

  (let [res (->> ($< task end.after:-7d status:completed rc.context=none export)
                 (json/decode)
                 (map keyword-keys))]))

(defn remove-duplicate [acc x]
  (if (= (last acc) x) acc
    (array/push acc x)))

(defn- get-level [prefix]
  (cond
   (= "" prefix) 0
   (->> (string/trim prefix ".")
        (string/find-all ".")
        (length)
        (+ 1))))

(test (get-level "") 0)
(test (get-level "arch") 1)
(test (get-level "arch.tst") 2)
(test (get-level "arch.tst.") 2)

(defn- format-by-level [str level]
  (-> (string/split "." str)
      (get level)))

(test (format-by-level "arch" 0) "arch")
(test (format-by-level "arch.test" 1) "test")
(test (format-by-level "arch.test.ing" 1) "test")
(test (format-by-level "arch.test.ing" 2) "ing")
(test (format-by-level "arch" 2) nil)


# TODO(optimize): Dong call taskwarrior everytime calling this function.
#                 Instead, call it once and store the result in a dyn :all-projects
(defn get-next-level-projects [prefix & flags]
  """
  Returns a lists of projects for the next 'level'
  given the prefix

  flags: :only-pending
  """
  (default prefix "")
  (def level (get-level prefix))
  (def only-pending (contains? flags :only-pending))
  (def filter-string (if only-pending "(status:pending)" "(status:pending or end:-365d)"))
  (->> ($< task ,filter-string _unique project)
       (string/split "\n")

       # Remove empty stuff
       (filter |(not (empty? $)))

       # Filter on prefix
       (filter |(string/has-prefix? prefix $))

       # Format to get correct level
       (map |(format-by-level $ level))

       # Remove duplicates
       (sort)
       (reduce remove-duplicate @[])

       # Remove empty stuff
       (filter |(not (empty? $)))))


(comment

  (get-next-level-projects "arch.learning")

  # (get-projects)

  (get-last-seven-days)

  (search "pro:arch test")

  (length (get-last-seven-days))
  (get-today)
  (get-item "0565502a-7329-4786-a919-7649c5")

  (length (search "allow pro:arch.taskwarrior.web")))
