(use joy)
(use judge)
(use ./utils)
(use ./components)
(import ./chart :as chart)
(import ./taskwarrior :as task)
(import ./git :as git)
(use time)


# Layout
(defn app-layout [{:body body :request request}]
  (text/html
    (doctype :html5)
    [:html {:lang "en"}
     [:head
      [:title "taskwarriorweb"]
      [:meta {:charset "utf-8"}]
      [:meta {:name "viewport" :content "width=device-width, initial-scale=1"}]
      [:meta {:name "csrf-token" :content (csrf-token-value request)}]
      [:link {:href "/app.css" :rel "stylesheet"}]
      [:link {:href "https://cdn.jsdelivr.net/npm/@picocss/pico@1/css/pico.min.css" :rel "stylesheet"}]
      [:script {:src "/app.js" :defer ""}]
      [:script {:src "https://unpkg.com/htmx.org@1.9.5"}]]
     [:body
       body]]))


# Routes
(route :get "/" :home)
(route :get "/git-status" :git-status)
(route :post "/git-pull" :git-pull)
(route :post "/git-force-pull" :git-force-pull)
(route :post "/git-push" :git-push)
(route :get "/get-content" :content)
(route :get "/complete/:uuid" :complete)
(route :get "/modify/:uuid" :modify)
(route :get "/delete/:uuid" :delete)
(route :post "/modify/:uuid" :modify-post)
(route :post "/add" :add)
(route :get "/error" :error-page)
(route :get "/search" :search)
(route :post "/search" :search-results)
(route :get "/completed" :completed)

# components
(route :get "/components/custom-input-button" custom-input-button-handler)

(defn display-project [p]
  (default p "")
  (-> (string/split "." p) (get 0)))

(defn show-tags [tags]
  (default tags @[])
  (string/join (map |(string "+" $) tags) " "))

(test (show-tags nil) "")
(test (show-tags @[]) "")
(test (show-tags @["test" "hey"]) "+test +hey")

(defn display-done-bar [dones todos]
  (if (and (zero? dones) (zero? todos)) ""
    (let [donebar     (string/repeat "▰" dones) 
          notdonebar  (string/repeat "▱" todos)]
      (string donebar notdonebar))))

(defn to-table [items]
  (let [rows (map (fn [{:description desc
                        :project p
                        :urgency u
                        :due due
                        :sceduled sch
                        :uuid uuid}]
                      [:tr
                         [:td desc]
                         [:td p]
                         [:td (display-time due)]
                         [:td (display-time sch)]
                         [:td (math/floor u)]
                         [:td [:a {:href (string "/edit/" uuid)} "edit"]]])
                  items)]
    [:table {:role "grid"}
      [:thead
       [:tr
         [:th "Description"]
         [:th "Project"]
         [:th "Due"]
         [:th "Scheduled"]
         [:th "Urgency"]
         [:th "edit"]]]
      [:tbody rows]]))

(defn git-status-wrapper [content]
  [:div {:style "float: right; height: 50px; margin: 10px;" :id "git-status"}
    content])
  
(defn to-table-mobile [items &opt options]
  "Only showing description, project and urgency"
  (default options {})
  (let [allow-modification  (get options :allow-modification true)
        show-urgency        (get options :show-urgency true)
        show-scheduled      (get options :show-scheduled true)
        show-header         (get options :show-header true)
        rows (map (fn [{:description desc
                        :project p
                        :urgency u
                        :due due
                        :sceduled sch
                        :uuid uuid}]
                      [:tr {:data-target (string "modal-" uuid)
                            :onClick "toggleModal(event)"}
                         [:td desc]
                         [:td {:style "white-space: pre-line"} (display-project p)]
                         (when show-urgency
                           [:td (math/floor u)])])
                  items)

          modals (map (fn [{:description desc
                            :project p
                            :urgency u
                            :due due
                            :recur recur
                            :scheduled sch
                            :end end
                            :tags tags
                            :uuid uuid}]
                          [:dialog {:id (string "modal-" uuid)}
                            [:article {:style "width: 100%;"}
                              [:header
                               [:h4 desc]]
                              [:ul
                                [:li (string "project: " p)]
                                (when show-urgency
                                  [:li (string "urgency: " (math/floor u))])
                                (when (exist? recur)
                                  [:li (string "recur: " recur)])
                                (when (exist? tags)
                                  [:li (string "tags: " (show-tags tags))])
                                (when (and show-scheduled (exist? sch))
                                  [:li (string "scheduled: " (display-time sch))])
                                (when (exist? due)
                                  [:li (string "due: " (display-time due))])
                                (when (exist? end)
                                  [:li (string "end: " (display-time end))])]
                              (when allow-modification
                                [:footer
                                   [:a {:href (string "/delete/" uuid)
                                        :role "button"
                                        :class "secondary"} "delete"]
                                   [:a {:href (string "/modify/" uuid)
                                        :role "button"
                                        :class "primary"} "modify"]
                                   [:a {:href (string "/complete/" uuid)
                                        :role "button"
                                        :class "primary"} "Complete"]])]])
                      items)]
    [[:table {:role "grid"}
       [:thead
        [:tr
          [:th (if show-header "Description" "")]
          [:th (if show-header "Project" "")]
          (when (and show-urgency show-header)
            [:th ""])]]
       [:tbody rows]
      modals]]))

(defn to-table-mobile-inbox [items]
  "Only showing description"
  (let [rows (map (fn [{:description desc
                        :uuid uuid}]
                      [:tr
                         [:td desc]
                         [:td
                          [:a {:href (string "/modify/" uuid)} "Edit"]]])
                  items)]
    [:table {:role "grid"}
      [:thead
       [:tr
         [:th "Description"]
         [:th ""]]]
      [:tbody rows]]))

(defn navbar []
  [:nav
   [:ul
    [:li ""]]
   [:ul
    [:li [:a {:href "/completed" :class "secondary"} "completed"]]
    [:li [:a {:href "/search" :class "secondary"} "search"]]
    [:li [:a {:href "/" :class "secondary"} "home"]]]])

(defn show-tasks [&opt git-status]
  (default git-status {:load? true})
  (let [today (task/get-today)
        inbox (task/get-inbox)
        done  (task/get-done-today)]
    [:div {:id "content"}
      (git-status-wrapper
         (git/show-status git-status))
      # Today
      [:h4 "Today"
        [:span {:style "font-size: 12px; margin-left: 10px;"}
          (string (length done) "/" (+ (length today) (length done)))]]
      # Inbox
      (when (not (= (length inbox) 0))
        [[:h4 "Inbox"]
         (to-table-mobile-inbox inbox)])
      (to-table-mobile today)]))

(defn modify-post [request]
  """
  There are two ways to modify a task:
  - custom input (name)
  - or by using the form (scheduled, due, project)
  """
  (let [uuid          (get-in request [:params :uuid])
        modify-string (get-in request [:body :modify])
        referer       (get-in request [:headers "Referer"])
        due           (get-in request [:body :due])
        scheduled     (get-in request [:body :scheduled])
        # project       (get-in request [:body :project]) TODO
        [success err] (protect (cond
                                 (not (nil? modify-string)) (task/modify-custom-string uuid modify-string)
                                 (task/modify uuid scheduled due)))]
    (if success
      (url-redirect referer) # Redirect back to where you came from
      (redirect-to :error-page {:? {:reason (string "could not modify item: " err)}}))))

(defn add [request]
  (let [desc (get-in request [:body :description])
        [success err] (protect (task/add desc))]
    (if success
      (redirect-to :home)
      (redirect-to :error-page {:? {:reason (string "could not modify item: " err)}}))))

(defn modify [request]
  (let [uuid  (get-in request [:params :uuid])
        [success v] (protect (task/get-item uuid))
        id (string "modify-" uuid)
        path (string "/modify/" uuid)]
    (if (not success) (redirect-to :error-page {:? {:reason v}})
      [:main {:class "container"}
        (navbar)
        [:a {:href (string "/delete/" uuid)
              :role "button"
              :style "float: right"
              :class "secondary"} "delete"]
        [:h4 (v :description)]
        [:ul
          [:li (string "project: " (v :project))]
          [:li (string "urgency: " (math/floor (v :urgency)))]
          [:li (string "recur: " (v :recur))]
          [:li (string "scheduled: " (display-time (v :scheduled)))]
          [:li (string "tags: " (show-tags (v :tags)))]
          [:li (string "due: " (display-time (v :due)))]]
        [:form {:action path :method "post" :id id}
          (date-picker "scheduled" (v :scheduled))
          (date-picker "due" (v :due))
          (project-picker (v :project))
          (custom-input-button id)
          [:br]
          [:button {:type "submit"} "Modify"]]])))

(defn delete [request]
  (let [uuid        (get-in request [:params :uuid])
        [success v] (protect (task/delete uuid))]
    (if success
      (redirect-to :home)
      (redirect-to :error-page {:? {:reason v}}))))


(defn complete [request]
  (let [uuid        (get-in request [:params :uuid])
        [success v] (protect (task/complete uuid))]
    (if success
      (redirect-to :home)
      (redirect-to :error-page {:? {:reason v}}))))

(defn error-page [request]
  (let [reason (get-in request [:query-string :reason])]
    [:main {:class "container"}
      (navbar)
      [:h3 "Error"]
      [:p reason]]))

(defn content [request]
  (let [g (git/get-status)]
    (show-tasks g)))

(defn add-modal []
  [[:button {:style "position: fixed;
                     bottom: 20px;
                     right: 20px;
                     width: 66px;
                     font-size: 40px;
                     padding: 0px;
                     margin: 0px;"
             :data-target "modal-add"
             :onClick "toggleModal(event)"} "+"]
   [:dialog {:id "modal-add"}
     [:article {:style "width: 100%;"}
       [:header
          [:h4 "Add task"]]
       [:form {:action "/add" :method "post"}
         [:input {:type "text" :name "description"} ""]
         [:button {:type "submit"} "Add"]]]]])

(defn search-results [request]
  (let [s (get-in request [:body :search])
        [success v] (protect (task/search s))]
    (if (not success)
      [:p (string "ERROR: " v)]
      [[:p (string "showing: " (length v))
         (to-table-mobile v)]])))

(defn search [request]
  [:main {:class "container"}
    (navbar)
    [:input {:hx-post "/search"
             :name "search"
             :hx-trigger "keyup changed delay:500ms, search" 
             :hx-target "#search-results"}]
    [:div {:id "search-results"}]])

(defn summary-table [items]
  (let [projects (get-root-projects items)]
    [:table {:style "width: 100px; float: right;"}
       [:tbody
          (map (fn [p]
                 [:tr
                   [:td p]
                   [:td (length (filter |(is-project? $ p) items))]]) projects)]]))


(defn completed [request]
  (let [done (task/get-done-today)]
    [:main {:class "container"}
      (navbar)
      [:h4 {:style "float: left;"} (string "today (" (length done) ")")]
      (summary-table done)
      (to-table-mobile done {:allow-modification false
                             :show-scheduled false
                             :show-header false
                             :show-urgency false})
      [:div {:style "margin-top: 100px;"}
        (chart/completed-last-seven-days)]]))

(defn home [request]
  [:main {:class "container"}
    (navbar)
    (show-tasks)
    (add-modal)])

(defn git-status [request]
  (-> (git/get-status)
      (git/show-status)
      (protect-error-page)))

(defn git-pull [request]
  (protect-error-page (git/pull-changes))
  (show-tasks (git/get-status)))

(defn git-force-pull [request]
  (protect-error-page (git/force-pull-changes))
  (show-tasks (git/get-status)))

(defn git-push [request]
  (protect-error-page (git/push-changes))
  (show-tasks (git/get-status)))

# Middleware
(def app (-> (handler)
             (layout app-layout)
             (with-session)
             (extra-methods)
             (query-string)
             (body-parser)
             (json-body-parser)
             (server-error)
             (x-headers)
             (static-files)
             (not-found)
             (logger)))


# Server
(defn main [& args]
  (let [port (get args 1 (os/getenv "PORT" "9001"))
        host (get args 2 (os/getenv "HOST" "localhost"))]
    (print "Starting server on " host ":" port)
    (server app port host)))
