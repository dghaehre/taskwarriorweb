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
  (sync)
  (let [output ($< task status:pending rc.context=none pro: export)
        json (json/decode output)]
    (map keyword-keys json)))

(defn get-done-today []
  (sync)
  (let [output ($< task status:completed rc.context=none end.after:tod export)
        json (json/decode output)]
    (map keyword-keys json)))

(defn get-item [uuid]
  (sync)
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
  (modify-custom-string uuid (string "project:" project))
  (sync))

(defn add [description]
  (default description "")
  (if (= "" description) (error "no description given")
    (do
      ($ task rc.context=none add ,description)
      (sync))))
    

(defn complete [uuid]
  ($ task done ,uuid)
  (sync))

(defn delete [uuid]
  ($ task rc.confirmation=off rm ,uuid)
  (sync))

# Broken at year boundaries
# Is based on :year-day
(defn group-by-days [items]
  (defn add-day-since-today [i]
    (as-> (get i :end) _
          (time/parse "%Y%m%dT%H%M%S%z" _ "EUROPE/OSLO")
          (os/date _ :local)
          (get _ :year-day)
          (merge {:day _} i)))
  (as-> (map add-day-since-today items) _
        (partition-by |(get $ :day) _)
        (sorted-by |(-> (get $ 0)
                        (get :day)) _)))

(defn get-last-seven-days []
  (->> ($< task end.after:-7d status:completed rc.context=none export)
       (json/decode)
       (map keyword-keys)
       (group-by-days)))

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
