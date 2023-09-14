(use sh)
(import json)

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

(comment
  (get-today)
  (get-item "0565502a-7329-4786-a919-7649c5")

  (length (search "allow pro:arch.taskwarrior.web")))
