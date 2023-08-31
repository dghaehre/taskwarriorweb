(use sh)

(defmacro git [& args]
  (let [git-dir (string (os/getenv "HOME") "/.task/.git")]
    ~($< git --git-dir ,git-dir ,;args)))

(defn get-status []
  (let [branch (-> (git rev-parse --abbrev-ref HEAD)
                   (string/trim))
        local (as-> (git status) _
                    (string/split "\n" _)
                    (reverse _)
                    (get _ 1)
                    (string/has-prefix? "nothing to commit, working tree clean" _)
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
  
(defn show-status [{:remote? r :local? l}]
  (cond
    (and (not r) (not l)) [:span {:style "color: green"} "🟢"]
    (and r l)             [:span "💀"]

    (and r (not l))       [:span
                            [:span {:style "float: right;"} "🟠"]
                            [:br]
                            [:a {:href "/git-pull"} "Pull changes"]]

    (and (not r) l)       [:span
                            [:span {:style "float: right;"} "🟡"]
                            [:br]
                            [:a {:href "/git-pull"} "Push changes"]]
    [:span "🤷"]))
