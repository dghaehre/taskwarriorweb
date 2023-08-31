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

(defn get-git-status []
  (let [branch (-> (git rev-parse --abbrev-ref HEAD)
                   (string/trim))
        local (as-> (git status) _
                    (string/split "\n" _)
                    (reverse _)
                    (get _ 1)
                    (or (string/has-prefix? "no changes added to commit" _)
                        (string/has-prefix? "nothing to commit, working tree clean" _))
                    (not _))
        remote (do
                 (git fetch origin ,branch)
                 (->> (git status)
                      (string/find "Your branch is behind")
                      (nil?)
                      (not)))]
    {:remote? remote # Do we have remote changes
     :local? local # Do we have local changes
     :branch branch}))

(comment
  (as-> (git status) _
        (string/split "\n" _)
        (reverse _)
        (get _ 1)
        (or (string/has-prefix? "no changes added to commit" _)
            (string/has-prefix? "nothing to commit, working tree clean" _))
        (not _))
  (get-git-status))
  
  
