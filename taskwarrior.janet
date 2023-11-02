(use sh)
(import json)
(use time)
(use judge)

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

(defn search [s]
  (let [output ($< task status:pending rc.context=none ,s export)
        json (json/decode output)]
    (map keyword-keys json)))

(comment
  (search "pro:arch test"))

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

(defn modify [uuid scheduled due]
  (modify-custom-string uuid (string "scheduled:" scheduled))
  (modify-custom-string uuid (string "due:" due)))

(defn add [description]
  (default description "")
  (if (= "" description) (error "no description given")
    ($ task rc.context=none add ,description)))

(defn complete [uuid]
  ($ task done ,uuid))

(defn delete [uuid]
  ($ task rc.confirmation=off rm ,uuid))

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

# (defn get-projects [&opt prefix]
#   (let [level (if (nil? prefix) 0
#                   (length (string/find-all "." prefix)))
#         projects (->> ($< task _unique project)
#                       (string/split "\n")
#                       (filter |(not (empty? $))))
#         filtered (if (nil? prefix) projects
#                      (-> (filter |(string/has-prefix? prefix $) projects)))]
#     (->> filtered
#          (map |(get (string/split "." $) level)))))
#     # (if (nil? prefix) projects
#     #    (-> (filter |(string/has-prefix? prefix $) projects)))))

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


(defn get-next-level-projects [&opt prefix]
  """
  Returns a lists of projects for the next 'level'
  given the prefix
  """
  (default prefix "")
  (def level (get-level prefix))
  (->> ($< task "(status:pending or end:-365d)" _unique project)
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

  (def i @{:description "Support currency from portal" :end "20230922T073356Z" :entry "20230914T075559Z" :id 0 :modified "20230922T073358Z" :project "vipps.beompenger.notification-service" :status "deleted" :test "sdfsdf" :urgency 1.04384 :uuid "329f56a3-ce3b-4e33-947f-0b0bd670b08a"})

  (length (get-last-seven-days))
  (get-today)
  (get-item "0565502a-7329-4786-a919-7649c5")

  (length (search "allow pro:arch.taskwarrior.web")))
