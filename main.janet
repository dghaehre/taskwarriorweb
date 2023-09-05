(use joy)
(use ./utils)
(import ./taskwarrior :as task)
(import ./git :as git)


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
(route :get "/error" :error-page)

# TODO
(defn display-time [t]
  (string t))

(defn display-project [p]
  (default p "")
  (-> (string/split "." p) (get 0)))

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
  
(defn to-table-mobile [items]
  "Only showing description, project and urgency"
  (let [rows (map (fn [{:description desc
                        :project p
                        :urgency u
                        :due due
                        :sceduled sch
                        :uuid uuid}]
                      [:tr {:data-target (string "modal-" uuid)
                            :onClick "toggleModal(event)"}
                         [:td desc]
                         [:td {:style "white-space: pre-line"} (display-project p)]
                         [:td (math/floor u)]])
                  items)

          modals (map (fn [{:description desc
                            :project p
                            :urgency u
                            :due due
                            :sceduled sch
                            :uuid uuid}]
                          [:dialog {:id (string "modal-" uuid)}
                            [:article {:style "width: 100%;"}
                              [:header
                               [:h4 desc]]
                              [:ul
                                [:li (string "project: " p)]
                                [:li (string "urgency: " (math/floor u))]
                                [:li (string "scheduled: " (display-time sch))]
                                [:li (string "due: " (display-time due))]]
                              [:footer
                                 [:a {:href "#cancel"
                                      :role "button"
                                      :class "secondary"
                                      :data-target (string "modal-" uuid)
                                      :onClick "toggleModal(event)"} "cancel"]
                                 [:a {:href (string "/complete/" uuid)
                                      :role "button"
                                      # :data-target (string "modal-" uuid)
                                      # :onClick "toggleModal(event)"
                                      :class "primary"} "Complete"]]]])
                      items)]
    [[:table {:role "grid"}
       [:thead
        [:tr
          [:th "Description"]
          [:th "Project"]
          [:th ""]]]
       [:tbody rows]
      modals]]))

(defn to-table-mobile-inbox [items]
  "Only showing description"
  (let [rows (map (fn [{:description desc
                        :uuid uuid}]
                      [:tr {:hx-get (string "/open/" uuid)}
                         [:td desc]])
                  items)]
    [:table {:role "grid"}
      [:thead
       [:tr
         [:th "Description"]]]
      [:tbody rows]]))

(defn show-tasks []
  (let [today (task/get-today)
        inbox (task/get-inbox)
        done  (task/get-done-today)]
    [:div {:id "content"}
      # Inbox
      (when (not (= (length inbox) 0))
        [[:h3 "Inbox"]
         (to-table-mobile-inbox inbox)])
      # Today
      [:h3 "Today"]
      (to-table-mobile today)
      # Update button
      [:button {:hx-get "/get-content"
                :hx-trigger "click"
                :hx-swap "outerHTML"
                :hx-target "#content"
                :style "float: right; margin: 10px; width: 60px;"}
       [:span {:class "hide-in-flight"} "⬇"]
       [:span {:class "htmx-indicator"} "⚪"]]
      # Footer
      [:p {:class "code"}
        [:p (string "✅ today: " (length done))]
        [:p (string "showing " (length today) " tasks")]]]))

(defn complete [request]
  (let [uuid        (get-in request [:params :uuid])
        [success v] (protect (task/complete uuid))]
    (if success
      (redirect-to :home)
      (redirect-to :error-page {:? {:reason v}}))))

(defn error-page [request]
  (let [reason (get-in request [:query-string :reason])]
    [:main
      [:h3 "Error"]
      [:p reason]]))

(defn content [request]
  (show-tasks))

(defn home [request]
  [:main
    (git-status-wrapper
       [:span {:hx-get "/git-status" :hx-trigger "load"} "⚪"])
    (show-tasks)])

(defn git-status [request]
  (-> (git/get-status)
      (git/show-status)
      (protect-error-page)))

(defn git-pull [request]
  (protect-error-page (git/pull-changes))
  (git/show-status (git/get-status)))

(defn git-force-pull [request]
  (protect-error-page (git/force-pull-changes))
  (git/show-status (git/get-status)))

(defn git-push [request]
  (protect-error-page (git/push-changes))
  (git/show-status (git/get-status)))

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
