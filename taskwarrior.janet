(use sh)
(import json)

(defn keyword-keys [m]
  "Make all keys in a map keywords"
  (var result @{})
  (loop [[key value] :pairs m]
    (set (result (keyword key)) value))
  result)

(defmacro git [& args]
  (let [git-dir (string (os/getenv "HOME") "/.task/.git")]
    ~($< git --git-dir ,git-dir ,;args)))

(defn get-today []
  (let [output ($< task scheduled.before:eod export ready)
        json (json/decode output)]
    (map keyword-keys json)))
