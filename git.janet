(use sh)
(use judge)

# TODO: doesnt work as intended
(defmacro git [& args]
  (let [git-dir (string (os/getenv "HOME") "/.task/.git")]
    ~($< git -C ,git-dir --git-dir ,git-dir ,;args)))

(defn get-branch []
  (-> (git rev-parse --abbrev-ref HEAD)
      (string/trim)))

# TODO: doesnt work as intended
(defn push-changes []
  (let [branch (get-branch)]
    (git add .)
    (git commit -m "update from taskwarriorweb")
    (git push origin ,branch)))

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
    {:remote? remote # Do we have remote changes
     :local? local # Do we have local changes
     :branch branch}))


(defn show-status [{:remote? r :local? l}]
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

(test (show-status {:remote? true :local? true}) [:span "\xF0\x9F\x92\x80"])
(test (show-status {:remote? true :local? false})
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

  (as-> (git status) _
              (string/split "\n" _)
              (reverse _))
              # (get _ 1)
              # (string/has-prefix? "nothing to commit, working tree clean" _))

  (git log --help)

  (get-status)

  (show-status {:remote? true :local? false}))
  
