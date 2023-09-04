(use sh)
(use judge)

(def git-dir (string (os/getenv "HOME") "/.task"))

(defmacro git [& args]
  ~($< git -C ,git-dir ,;args))

(defn get-branch []
  (-> (git rev-parse --abbrev-ref HEAD)
      (string/trim)))

(defn push-changes []
  (let [branch (get-branch)]
    (git add ,git-dir)
    (git commit -m "update from taskwarriorweb")
    (git push origin ,branch)))

(defn pull-changes []
  (let [branch (get-branch)]
    (git pull origin ,branch)))

(defn force-pull-changes []
  (let [branch (get-branch)]
    (git reset --hard HEAD) # Reset everything
    (git pull origin ,branch)))

(defn get-status []
  (let [branch (get-branch)
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
    {:remote-changes? remote # Do we have remote changes
     :local-changes? local # Do we have local changes
     :branch branch}))


(defn show-status [{:remote-changes? r :local-changes? l}]
  (match [r l]
    [false false]  [:span {:hx-get "/git-status" :hx-trigger "click"}
                     [:span {:class "hide-in-flight"}
                       [:span {:style "color: green"} "🟢"]]
                     [:span {:class "htmx-indicator" :style "float: right;"} "⚪"]]
    [true true]   [:span {:hx-post "/git-pull-force" :hx-trigger "click"}
                     [:span {:class "hide-in-flight"}
                       [:span {:style "float: right;"} "💀"]
                       [:br]
                       [:span  "Force pull changes"]]
                     [:span {:class "htmx-indicator" :style "float: right;"} "⚪"]]
    [true false]   [:span {:hx-post "/git-pull" :hx-trigger "click"}
                     [:span {:class "hide-in-flight"}
                       [:span {:style "float: right;"} "🟡"]
                       [:br]
                       [:span  "Pull changes"]]
                     [:span {:class "htmx-indicator" :style "float: right;"} "⚪"]]
    [false true]   [:span {:hx-post "/git-push" :hx-trigger "click"}
                     [:span {:class "hide-in-flight"}
                       [:span {:style "float: right;"} "🟡"]
                       [:br]
                       [:span  "Push changes"]]
                     [:span {:class "htmx-indicator" :style "float: right;"} "⚪"]]
    [:span "🤷"]))

(test (show-status {:remote-changes? true :local-changes? true}) [:span "\xF0\x9F\x92\x80"])
(test (show-status {:remote-changes? true :local-changes? false})
  [:span
   [:span
    {:style "float: right;"}
    "\xF0\x9F\x9F\xA0"]
   [:br]
   [:a {:href "/git-pull"} "Pull changes"]])

(comment
  (as-> (git status) _
        (string/split "\n" _)
        (reverse _)
        (get _ 1)
        (or (string/has-prefix? "no changes added to commit" _)
            (string/has-prefix? "nothing to commit, working tree clean" _))
        (not _))

  (macex '(git status))

  (get-status)
  (git status)
  (git add ,git-dir)

  (push-changes)

  (as-> (git status) _
              (string/split "\n" _)
              (reverse _))
              # (get _ 1)
              # (string/has-prefix? "nothing to commit, working tree clean" _))

  (git log --help)

  (get-status)

  (show-status {:remote-changes? true :local-changes? false}))
  
