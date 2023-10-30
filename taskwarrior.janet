(use sh)
(import json)
(use time)

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

(defn modify [uuid modify-string]
  ($ task ,uuid mod ,modify-string))

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

(comment

  (get-last-seven-days)

  (search "pro:arch test")

  (def i @{:description "Support currency from portal" :end "20230922T073356Z" :entry "20230914T075559Z" :id 0 :modified "20230922T073358Z" :project "vipps.beompenger.notification-service" :status "deleted" :test "sdfsdf" :urgency 1.04384 :uuid "329f56a3-ce3b-4e33-947f-0b0bd670b08a"})

  (length (get-last-seven-days))
  (get-today)
  (get-item "0565502a-7329-4786-a919-7649c5")

  (length (search "allow pro:arch.taskwarrior.web")))
