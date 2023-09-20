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
  (git restore ,git-dir)
  (git reset --hard HEAD)
  (pull-changes))

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

(defn git-status-action-new [{:remote-changes? r :local-changes? l}]
  (match [r l]
    [false false] {:action {:hx-get "/get-content"}
                   :class "secondary outline git-good"
                   :text "Fetch"}
    [true false]  {:action {:hx-post "/git-pull"}
                   :class "secondary outline git-pull"
                   :text "Pull"}
    [false true]  {:action {:hx-post "/git-push"}
                   :class "secondary outline git-pull"
                   :text "Push"}
    [true true]   {:action {:hx-post "/git-force-pull"}
                   :class "secondary outline git-error"
                   :text "Force pull"}
    {:action {:hx-get "/get-content"}
     :class "secondary outline"
     :text "ooops"}))

(defn show-status [g]
  (let [{:action action
         :class class
         :text text} (git-status-action-new g)
        load (get g :load?)]
    [:button (merge action
                    {:hx-trigger (if load "load" "click")
                     :hx-swap "outerHTML"
                     :hx-target "#content"
                     :role "button"
                     :style "width: 130px"
                     :class class})
       [:span {:class "hide-in-flight"} text]
       [:span {:class "htmx-indicator"} [:span {:aria-busy "true"}]]]))

(test (show-status {:remote-changes? true :local-changes? true})
  [:button
   @{:class "secondary outline git-error"
     :hx-post "/git-force-pull"
     :hx-swap "outerHTML"
     :hx-target "#content"
     :hx-trigger "click"
     :role "button"
     :style "width: 130px"}
   [:span
    {:class "hide-in-flight"}
    "Force pull"]
   [:span
    {:class "htmx-indicator"}
    [:span {:aria-busy "true"}]]])
(test (show-status {:load? true})
  [:button
   @{:class "secondary outline"
     :hx-get "/get-content"
     :hx-swap "outerHTML"
     :hx-target "#content"
     :hx-trigger "load"
     :role "button"
     :style "width: 130px"}
   [:span
    {:class "hide-in-flight"}
    "ooops"]
   [:span
    {:class "htmx-indicator"}
    [:span {:aria-busy "true"}]]])
(test (show-status {:remote-changes? true :local-changes? false})
  [:button
   @{:class "secondary outline git-pull"
     :hx-post "/git-pull"
     :hx-swap "outerHTML"
     :hx-target "#content"
     :hx-trigger "click"
     :role "button"
     :style "width: 130px"}
   [:span {:class "hide-in-flight"} "Pull"]
   [:span
    {:class "htmx-indicator"}
    [:span {:aria-busy "true"}]]])

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
  
